package Lacuna::RPC::Building::SpacePort;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::RPC::Building';
use Lacuna::Constants qw(SHIP_TYPES);
use Lacuna::Util qw(format_date);
use Data::Dumper;

use feature "switch";

sub app_url {
    return '/spaceport';
}

sub model_class {
    return 'Lacuna::DB::Result::Building::SpacePort';
}

sub find_target {
    my ($self, $target_params) = @_;
    unless (ref $target_params eq 'HASH') {
        confess [-32602, 'The target parameter should be a hash reference. For example { "star_id" : 9999 }.'];
    }
    my $target;
    if (exists $target_params->{star_id}) {
        $target = Lacuna->db->resultset('Map::Star')->find($target_params->{star_id});
    }
    elsif (exists $target_params->{star_name}) {
        $target = Lacuna->db->resultset('Map::Star')->search({ name => $target_params->{star_name} }, {rows=>1})->single;
    }
    if (exists $target_params->{body_id}) {
        $target = Lacuna->db->resultset('Map::Body')->find($target_params->{body_id});
    }
    elsif (exists $target_params->{body_name}) {
        $target = Lacuna->db->resultset('Map::Body')->search({ name => $target_params->{body_name} }, {rows=>1})->single;
    }
    elsif (exists $target_params->{x}) {
        $target = Lacuna->db->resultset('Map::Body')->search({ x => $target_params->{x}, y => $target_params->{y} }, {rows=>1})->single;
        unless (defined $target) {
            $target = Lacuna->db->resultset('Map::Star')->search({ x => $target_params->{x}, y => $target_params->{y} }, {rows=>1})->single;
        }
    }
    unless (defined $target) {
        confess [ 1002, 'Could not find the target.', $target];    
    }
    return $target;
}


# Get fleets not available to send to a target
sub view_unavailable_fleets {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            body_id         => shift,
            target          => shift,
            filter          => shift,
            sort            => shift,
        };
    }
    return $self->_view_fleets($args, 'unavailable');
}


# Get fleets available to send to a target
sub view_available_fleets {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            body_id         => shift,
            target          => shift,
            filter          => shift,
            sort            => shift,
        };
    }
    return $self->_view_fleets($args, 'available');
}

sub _view_fleets {
    my ($self, $args, $option) = @_;

    my $empire  = $self->get_empire_by_session($args->{session_id});
    my $body    = $self->get_body($empire, $args->{body_id});
    my $target  = $self->find_target($args->{target});

    my $filter  = $self->_fleet_filter_options( (defined $args->{filter} && ref $args->{filter} eq 'HASH') ? $args->{filter} : {} );
    my $sort    = $self->_fleet_sort_options( $args->{sort} // 'type' );

    my $attrs = {
        order_by    => $sort,
    };

    my $fleet_rs = Lacuna->db->resultset('Fleet')->search($filter, $attrs);
    $fleet_rs = $fleet_rs->search({
        task        => 'Docked',
        body_id     => $body->id,
    });
    my @available;
    my @unavailable;
    while (my $fleet = $fleet_rs->next) {
        $fleet->body($body);
        my $status = $fleet->get_status;
        eval{ $fleet->can_send_to_target($target) };
        my $reason = $@;
        if ($reason) {
            $status->{reason} = $reason;
            push @unavailable, $status;
        }
        else {
            push @available, $status;
            my $earliest_arrival = $fleet->earliest_arrival($target);
            $status->{earliest_arrival} = {
                month       => sprintf("%02d", $earliest_arrival->month),
                day         => sprintf("%02d", $earliest_arrival->day),
                hour        => sprintf("%02d", $earliest_arrival->hour),
                minute      => sprintf("%02d", $earliest_arrival->minute),
                second      => sprintf("%02d", $earliest_arrival->second),
            };
        }
    }
        
    my %out = (
        status      => $self->format_status($empire),
        available   => $option eq 'available' ? \@available : \@unavailable,
    );

    return \%out;
}




# Get a list of fleets that can be sent to a target
sub get_fleets_for {
    my ($self, $session_id, $body_id, $target_params) = @_;

    my $empire  = $self->get_empire_by_session($session_id);
    my $body    = $self->get_body($empire, $body_id);
    my $target  = $self->find_target($target_params);
    my $fleets  = Lacuna->db->resultset('Lacuna::DB::Result::Fleet');
    
    my @incoming;
    my $incoming_rs = $fleets->search({
        task                => 'Travelling', 
        direction           => 'out',
        'body.empire_id'    => $empire->id,
        },{ 
        join => 'body',
    });
    if ($target->isa('Lacuna::DB::Result::Map::Star')) {
        $incoming_rs = $incoming_rs->search({foreign_star_id => $target->id});
    }
    else {
        $incoming_rs = $incoming_rs->search({foreign_body_id => $target->id});
    }
    while (my $ship = $incoming_rs->next) {
        $ship->body($body) if ($ship->body_id == $body->id);
        push @incoming, $ship->get_status;
    }
    
    my $max_berth = $body->max_berth;

    my @unavailable;
    my @available;
    my $available_rs = $fleets->search( {task => 'Docked',
                                        body_id=>$body->id });
    while (my $ship = $available_rs->next) {
      $ship->body($body);
      eval{ $ship->can_send_to_target($target) };
      my $reason = $@;
      if ($reason) {
        push @unavailable, { ship => $ship->get_status, reason => $reason };
        next;
      }
      if ($ship->berth_level > $max_berth) {
        $reason = [ 1009, 'Max Berth Level to send from this planet is '.$max_berth ];
        push @unavailable, { ship => $ship->get_status, reason => $reason };
        next;
      }
      $ship->body($body);
      push @available, $ship->get_status($target);
    }
    
    my $max_ships = Lacuna->config->get('ships_per_fleet') || 20;

    my %out = (
        status              => $self->format_status($empire, $body),
        incoming            => \@incoming,
        available           => \@available,
        unavailable         => \@unavailable,
        fleet_send_limit    => $max_ships,
    );
    
    unless ($target->isa('Lacuna::DB::Result::Map::Star')) {
        my @orbiting;
        my $orbiting_rs = $fleets->search({task => [qw(Defend Orbiting)], body_id => $body->id, foreign_body_id => $target->id });
        while (my $ship = $orbiting_rs->next) {
            $ship->body($body);
            eval{ $ship->can_recall() };
                my $reason = $@;
                if ($reason) {
                    push @unavailable, { ship => $ship->get_status, reason => $reason };
                    next;
                }
            $ship->body($body);
            push @orbiting, $ship->get_status($target);
        }
        $out{orbiting} = \@orbiting;
    }

    if ($target->isa('Lacuna::DB::Result::Map::Body::Asteroid')) {
        my $platforms = Lacuna->db->resultset('Lacuna::DB::Result::MiningPlatforms')->search({asteroid_id => $target->id});
        while (my $platform = $platforms->next) {
            my $empire = $platform->planet->empire;
            if (defined $empire) {
                push @{$out{mining_platforms}}, {
                    empire_id   => $empire->id,
                    empire_name => $empire->name,
                };
            }
            else {
                $platform->delete;
            }
        }
    }
    if ( $target->isa('Lacuna::DB::Result::Map::Body::Asteroid') ||
         $target->isa('Lacuna::DB::Result::Map::Body::Planet') ) {
        my $excavators = Lacuna->db->resultset('Lacuna::DB::Result::Excavators')->search({body_id => $target->id});
        while (my $excav = $excavators->next) {
            my $empire = $excav->planet->empire;
            if (defined $empire) {
                push @{$out{excavators}}, {
                  empire_id   => $empire->id,
                  empire_name => $empire->name,
                };
            }
            else {
                $excav->delete;
            }
        }
    }
    
    return \%out;
}

sub send_ship {
    my ($self, $session_id, $ship_id, $target_params) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $target = $self->find_target($target_params);
    my $ship = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->find($ship_id);
    unless (defined $ship) {
        confess [1002, 'Could not locate that ship.'];
    }
    unless ($ship->body->empire_id == $empire->id) {
        confess [1010, 'You do not own that ship.'];
    }
    my $body = $ship->body;
    $body->empire($empire);
    $ship->can_send_to_target($target);
    if ($ship->hostile_action) {
        $empire->current_session->check_captcha;
    }
    $ship->send(target => $target);
    return {
        ship    => $ship->get_status,
        status  => $self->format_status($empire),
    }
}

sub find_arrival {
    my ($self, $arrival_params) = @_;

    my $now     = DateTime->now;
    my $year    = $now->year,
    my $month   = $now->month;
    my $mon_end = DateTime->last_day_of_month(year => $year, month => $month);
    my $day     = $arrival_params->{day};
    my $hour    = $arrival_params->{hour};
    my $minute  = $arrival_params->{minute};
    my $second  = $arrival_params->{second};

    if (not defined $day or $day < 1 or $day > $mon_end->day) {
        confess [1009, "Invalid day. [$day][".Dumper($arrival_params)."]"];
    }
    if (not defined $hour or $hour != int($hour) or $hour < 0 or $hour > 23) {
        confess [1002, 'Invalid hour.'];
    }
    if (not defined $minute or $minute != int($minute) or $minute < 0 or $minute > 59) {
        confess [1002, 'Invalid minute.'];
    }
    if (not defined $second or $second != 0 and $second != 15 and $second != 30 and $second != 45) {
        confess [1002, 'Invalid second. Must be 0, 15, 30 or 45'];
    }
    if ($day < $now->day) {
        # Then it must be a day next month
        $mon_end->add( days => $day);
        $year    = $mon_end->year;
        $month   = $mon_end->month;
    }
    my $arrival = DateTime->new(
        year    => $year,
        month   => $month,
        day     => $day,
        hour    => $hour,
        minute  => $minute,
        second  => $second,
    );
    return $arrival;
}

sub send_ship_types {
    my ($self, $session_id, $body_id, $target_params, $type_params, $arrival_params) = @_;

    my $empire  = $self->get_empire_by_session($session_id);
    my $body    = $self->get_body($empire, $body_id);
    my $target  = $self->find_target($target_params);
    my $arrival = $self->find_arrival($arrival_params);

    # calculate the total ships before the expense of any database operations.
    my $total_ships = 0;
    map {$total_ships += $_->{quantity}} @$type_params;
    my $max_ships = Lacuna->config->get('ships_per_fleet') || 20;
    if ($total_ships > $max_ships) {
        confess [1009, 'Too many ships for a fleet.'];
    }

    my $ship_ref;
    my $do_captcha_check = 0;
    foreach my $type_param (@$type_params) {
        foreach my $arg (qw(speed stealth combat quantity)) {
            confess [1002, "$arg cannot be negative."] if $type_param->{$arg} < 0;
            confess [1002, "$arg must be an integer."] if $type_param->{$arg} != int($type_param->{$arg});
        }
        my $type        = $type_param->{type};
        my $speed       = $type_param->{speed};
        my $stealth     = $type_param->{stealth};
        my $combat      = $type_param->{combat};
        my $quantity    = $type_param->{quantity};
        confess [1009, "Cannot send more than one excavator"] if ($type eq 'excavator' and $quantity > 1);

        # TODO Must check for valid berth levels
        # 
        my $ships_rs    = Lacuna->db->resultset('Ships')->search({
            body_id => $body->id,
            task    => 'Docked',
            type    => $type,
            speed   => $speed,
            stealth => $stealth,
            combat  => $combat,
        });
        if ($ships_rs->count < $quantity) {
            confess [1009, "Cannot find $quantity of $type ships."];
        }
        my @ships = $ships_rs->search(undef,{rows => $quantity});
        my $ship = $ships[0];
        # We only need to check one of the ships
        $ship->can_send_to_target($target);
        if (not $do_captcha_check and $ship->hostile_action) {
            $do_captcha_check = 1;
        }
        foreach my $ship (@ships) {
            $ship_ref->{$ship->id} = $ship;
        }
    }
    if ($do_captcha_check) {
        $empire->current_session->check_captcha;
    }
    # If we get here without exceptions, then all ships can be sent
    foreach my $ship (values %$ship_ref) {
        $ship->fleet_speed(1);
        $ship->send(target => $target, arrival => $arrival);
    }
    return $self->get_fleet_for($session_id, $body_id, $target_params);
}

sub send_fleet {
    my $self = shift;
    my $args = shift;
        
    if (ref($args) ne "HASH") {
        $args = {
            session_id  => $args,
            fleet_id    => shift,
            quantity    => shift,
            target      => shift,
            arrival_date=> shift,
        };
    }
    $args->{arrival_date} = {soonest => 1} if not defined $args->{arrival_date};
    
    my $empire  = $self->get_empire_by_session($args->{session_id});
    my $target  = $self->find_target($args->{target});
    my $qty     = $args->{quantity};
    my $fleet   = Lacuna->db->resultset('Fleet')->find({id => $args->{fleet_id}},{prefetch => 'body'});
    if (! defined $fleet) {
        confess [1002, 'Could not locate that fleet.'];
    }
    if ($fleet->body->empire->id != $empire->id) {
        confess [1010, 'You do not own that ship.'];
    }
    if (not defined $qty or $qty < 0 or int($qty) != $qty) {
        confess [1009, 'Quantity must be a positive integer'];
    }
    if ($qty > $fleet->quantity) {
        confess [1009, "You don't have that many ships in the fleet"];
    }
    if ($fleet->type eq 'excavator' and $qty > 1) {
        confess [1009, 'You can only send one excavator to a body'];
    }
    $fleet->can_send_to_target($target);
    if ($fleet->hostile_action) {
        $empire->current_session->check_captcha;
    }
    my $new_fleet = $fleet->split($qty); 

    if ($args->{arrival_date}{soonest}) {
        $new_fleet->send(target => $target);
    }
    else {
        my $month   = $args->{arrival_date}{month};
        my $date    = $args->{arrival_date}{date};
        my $hour    = $args->{arrival_date}{hour};
        my $minute  = $args->{arrival_date}{minute};
        my $second  = $args->{arrival_date}{second};
        if ($second != 0 and $second != 15 and $second != 30 and $second != 45) {
            confess [1009, 'Seconds can only be one of 0,15,30 or 45'];
        }
        if ($minute < 0 or $minute > 59 or $minute != int($minute)) {
            confess [1009, 'Minutes must be an integer between 0 and 59'];
        }
        if ($hour < 0 or $hour > 23 or $hour != int($hour)) {
            confess [1009, 'Hours must be an integer between 0 and 23'];
        }
        if ($month < 1 or $month > 12 or $month != int($month)) {
            confess [1009, 'Month must be an integer between 1 and 12'];
        }
        my $now = DateTime->now;
        my $month_now   = $now->month;
        my $year_now    = $now->year;
        my $year        = $year_now;
        # if it is for a date next year
        if ($month < $month_now) {
            $year = $year_now + 1;
        }
        my $arrival_date = DateTime->new(
            year        => $year,
            month       => $month,
            day         => $date,
            hour        => $hour,
            minute      => $minute,
            second      => $second,
        );
        my $earliest_arrival = DateTime->now->add(seconds=>$fleet->calculate_travel_time($target));
        if ($arrival_date < $earliest_arrival) {
            confess [1009, 'The fleet is not fast enough to arrive by that date'];
        }
        $new_fleet->send(target => $target, arrival => $arrival_date);
    }
    return {
        fleet   => $fleet->get_status,
        status  => $self->format_status($empire),
    };
}

sub recall_fleet {
    my $self = shift;
    my $args = shift;
        
    if (ref($args) ne "HASH") {
        $args = {
            session_id  => $args,
            fleet_id    => shift,
            quantity    => shift,
        };
    }
    my $empire  = $self->get_empire_by_session($args->{session_id});
    my $qty     = $args->{quantity};
    my $fleet   = Lacuna->db->resultset('Fleet')->find({id => $args->{fleet_id}},{prefetch => 'body'});
    if (! defined $fleet) {
        confess [1002, 'Could not locate that fleet.'];
    }
    if ($fleet->body->empire->id != $empire->id) {
        confess [1010, 'You do not own that ship.'];
    }
    if ($qty < 0 or int($qty) != $qty) {
        confess [1009, 'Quantity must be a positive integer'];
    }
    if ($qty > $fleet->quantity) {
        confess [1009, "You don't have that many ships in the fleet"];
    }
    $fleet->can_recall;

    my $target = $self->find_target({body_id => $fleet->foreign_body_id});

    my $new_fleet = $fleet->split($qty);
    $new_fleet->send(
        target      => $target,
        direction   => 'in',
    );
    my $body = $new_fleet->body;
    $body->update;
    # to satisfy 'view' get a Space Port
    $args->{building_id} = $body->spaceport->id;
    return $self->view($args);
}

sub recall_all {
  my ($self, $session_id, $building_id) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    my $body = $building->body;
    my @ships = $body->ships_orbiting->search(undef)->all;
    my @ret;
    for my $ship (@ships) {
        unless (defined $ship) {
            confess [1002, 'Could not locate that ship.'];
        }
        unless ($ship->body->empire_id == $empire->id) {
            confess [1010, 'You do not own that ship.'];
        }
        $body->empire($empire);
        $ship->can_recall();

        my $target = $self->find_target({body_id => $ship->foreign_body_id});
        $ship->send(
            target    => $target,
            direction  => 'in',
        );
        $ship->body->update;
    push @ret, {
      ship    => $ship->get_status,
    }
    }
    return {
    ships  => \@ret,
        status  => $self->format_status($empire),
    }
}

sub prepare_send_spies {
    my ($self, $session_id, $on_body_id, $to_body_id) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $on_body = $self->get_body($empire, $on_body_id);
    my $to_body = Lacuna->db->resultset('Lacuna::DB::Result::Map::Body')->find($to_body_id);
    
    unless ($to_body->empire_id) {
        confess [1009, "Cannot send spies to an uninhabited body."];
    }
    if ($to_body->empire->is_isolationist) {
        confess [ 1013, sprintf('%s is an isolationist empire, and must be left alone.',$to_body->empire->name)];
    }

    $empire->current_session->check_captcha;
    
    my $max_berth = $on_body->max_berth;
    unless ($max_berth) {
        $max_berth = 1;
    }

    my $ships = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search(
        {type => { in => [qw(spy_pod cargo_ship smuggler_ship dory spy_shuttle barge)]},
         task=>'Docked', body_id => $on_body_id,
         berth_level => {'<=' => $max_berth } },
        {order_by => 'name', rows=>100}
    );
    my @ships;
    while (my $ship = $ships->next) {
        push @ships, $ship->get_status($to_body);
    }

    my $spies = Lacuna->db->resultset('Lacuna::DB::Result::Spies')->search(
        {on_body_id => $on_body->id, empire_id => $empire->id },
        {order_by => 'name', rows=>100}
    );
    my @spies;
    while (my $spy = $spies->next) {
        $spy->on_body($on_body);
        if ($spy->is_available) {
            push @spies, $spy->get_status;
        }
    }

    return {
        status  => $self->format_status($empire),
        ships   => \@ships,
        spies   => \@spies,
    };
}

sub send_spies {
    my ($self, $session_id, $on_body_id, $to_body_id, $ship_id, $spy_ids) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $on_body = $self->get_body($empire, $on_body_id);
    my $to_body = Lacuna->db->resultset('Lacuna::DB::Result::Map::Body')->find($to_body_id);
    
    # make sure it's a valid target
    unless ($to_body->empire_id) {
        confess [ 1009, 'Cannot send spies to an uninhabited body.'];
    }
    if ($to_body->empire->is_isolationist) {
        confess [ 1013, sprintf('%s is an isolationist empire, and must be left alone.',$to_body->empire->name)];
    }

    $empire->current_session->check_captcha;

    # get the ship
    my $ship = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->find($ship_id);
    unless (defined $ship) {
        confess [1002, "Ship not found."];
    }
    unless ($ship->is_available) {
        confess [1010, "That ship is not available."];
    }
    my $max_berth = $on_body->max_berth;
    unless ($ship->berth_level <= $max_berth) {
        confess [1010, "Your spaceport level is not high enough to support a ship with a Berth Level of ".$ship->berth_level."."];
    }

    # check size
    unless (scalar(@{$spy_ids})) {
        confess [1013, "You can't send a ship with no spies."];
    }
    
    if ($ship->type eq 'spy_pod' && scalar(@{$spy_ids}) == 1) {
        # we're ok
    }
    elsif ($ship->type eq 'spy_shuttle' && scalar(@{$spy_ids}) <= 4) {
        # we're ok
    }
    elsif ($ship->hold_size <= (scalar(@{$spy_ids}) * 350)) {
        confess [1010, "The ship cannot hold the spies selected."];
    }
    
    # get a spies
    my @ids_sent;
    my @ids_not_sent;
    my $spies = Lacuna->db->resultset('Lacuna::DB::Result::Spies');
    foreach my $id (@{$spy_ids}) {
        my $spy = $spies->find($id);
        if ($spy->is_available) {
            if ($spy->empire_id == $empire->id) {
                my $arrives = DateTime->now->add(seconds=>$ship->calculate_travel_time($to_body));
                push @ids_sent, $spy->id;
                $spy->send($to_body->id, $arrives)->update;
            }
            else {
                push @ids_not_sent, $spy->id;
            }
        }
        else {
            push @ids_not_sent, $spy->id;
        }
    }

    # send it
    $ship->send(
        target      => $to_body,
        payload     => {spies => \@ids_sent }, # add the spies to the payload when we send, otherwise they'll get added again
    );

    return {
        ship            => $ship->get_status,
        spies_sent      => \@ids_sent,
        spies_not_sent  => \@ids_not_sent,
        status          => $self->format_status($empire, $on_body)
    };
}

sub prepare_fetch_spies {
    my ($self, $session_id, $on_body_id, $to_body_id) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $to_body = $self->get_body($empire, $to_body_id);
    my $on_body = Lacuna->db->resultset('Lacuna::DB::Result::Map::Body')->find($on_body_id);
    unless ($on_body->empire_id) {
        confess [1013, "Cannot fetch spies from an uninhabited planet."];
    }

    my $max_berth = $to_body->max_berth;
    unless ($max_berth) {
        $max_berth = 1;
    }

    my $ships = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search(
        {type => { in => [qw(spy_pod cargo_ship smuggler_ship dory spy_shuttle barge)]},
         task=>'Docked', body_id => $to_body_id,
         berth_level => {'<=' => $max_berth } },
        {order_by => 'name', rows=>100}
    );
    my @ships;
    while (my $ship = $ships->next) {
        push @ships, $ship->get_status($on_body);
    }
    
    my $spies = Lacuna->db->resultset('Lacuna::DB::Result::Spies')->search(
        {
            on_body_id => $on_body->id, 
            empire_id => $empire->id,
            -or => [
                task => { in => [ 'Idle', 'Counter Espionage' ], },
                -and => [
                    task => { in => [ 'Unconscious', 'Debriefing' ], },
                    available_on => { '<' => '\NOW()' }, 
                ],
            ],
        },
        {order_by => 'name', rows=>100}
    );
    my @spies;
    while (my $spy = $spies->next) {
        $spy->on_body($on_body);
        if ($spy->is_available) {
            push @spies, $spy->get_status;
        }
    }
    
    return {
        status  => $self->format_status($empire),
        ships   => \@ships,
        spies   => \@spies,
    };
}

sub fetch_spies {
    my ($self, $session_id, $on_body_id, $to_body_id, $ship_id, $spy_ids) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $to_body = $self->get_body($empire, $to_body_id);
    my $on_body = Lacuna->db->resultset('Lacuna::DB::Result::Map::Body')->find($on_body_id);

    my $max_berth = $to_body->max_berth;

    # get the ship
    my $ship = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->find($ship_id);
    unless (defined $ship) {
        confess [1002, "Ship not found."];
    }
    unless ($ship->is_available || ($ship->can_recall && $ship->foreign_body_id == $on_body_id)) {
        confess [1010, "That ship is not available."];
    }

    unless ($ship->berth_level <= $max_berth) {
        confess [1010, "Your spaceport level is not high enough to support a ship with a Berth Level of ".$ship->berth_level."."];
    }

    unless ($on_body->empire_id) {
        confess [1013, "Cannot fetch spies from an uninhabited planet."];
    }

    unless (scalar(@{$spy_ids})) {
        confess [1013, "You can't send a ship to collect no spies."];
    }
    
    # check size
    if ($ship->type eq 'spy_shuttle' && scalar(@{$spy_ids}) <= 4) {
        # we're ok
    }
    elsif ($ship->hold_size <= (scalar(@{$spy_ids}) * 350)) {
        confess [1013, "The ship cannot hold the spies selected."];
    }
    
    # send it
    $ship->send(
        target      => $on_body,
        payload     => { fetch_spies => $spy_ids },
    );

    return {
        ship    => $ship->get_status,
        status  => $self->format_status($empire, $to_body),
    };
}


sub view_fleets_travelling {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
        };
    }

    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});
                                                                    
    my $paging = $self->_fleet_paging_options( (defined $args->{paging} && ref $args->{paging} eq 'HASH') ? $args->{paging} : {} );
    my $filter = $self->_fleet_filter_options( (defined $args->{filter} && ref $args->{filter} eq 'HASH') ? $args->{filter} : {} );
    my $sort = $self->_fleet_sort_options( $args->{sort} // 'type' );

    my $attrs = {
        order_by => $sort,
    };
    $attrs->{rows} = $paging->{items_per_page} if ( defined $paging->{items_per_page} );
    $attrs->{page} = $paging->{page_number} if ( defined $paging->{page_number} );

    my $body = $building->body;

    my @travelling;
    my $fleets = $body->fleets_travelling->search($filter, $attrs);
    my $ships_travelling = 0;
    while (my $fleet = $fleets->next) {
        $fleet->body($body);
        push @travelling, $fleet->get_status;
        $ships_travelling += $fleet->quantity;
    }
    return {
        status                      => $self->format_status($empire, $body),
        number_of_fleets_travelling => $fleets->pager->total_entries,
        number_of_ships_travelling  => $ships_travelling,
        travelling                  => \@travelling,
    };
}

sub _fleet_paging_options {
    my ($self, $paging) = @_;
    for my $key ( keys %{ $paging } ) {
        # Throw away bad keys
        unless ($key ~~ [qw(page_number items_per_page no_paging)]) {
            delete $paging->{$key};
            next;
        }
    }
    if ($paging->{no_paging}) {
        $paging = {};
    }
    else {
        $paging->{page_number} ||= 1;
        $paging->{items_per_page} ||= 25;
    }
    return $paging;
}

sub _fleet_filter_options {
    my ($self, $filter) = @_;

    # Valid filter options include...
    my $options = {
        task    => [qw(Docked Building Mining Travelling Defend Orbiting),'Waiting On Trade','Supply Chain','Waste Chain'],
        tag     => [qw(Trade Colonization Intelligence Exploration War Mining SupplyChain WasteChain)],
        type    => [SHIP_TYPES],
    };

    # Pull in the list of fleet types by tag
    my %tag;
    for my $type ( SHIP_TYPES ) {
        my $fleet = Lacuna->db->resultset('Lacuna::DB::Result::Fleet')->new({ type => $type });
        for my $tag ( @{$fleet->build_tags} ) {
            push @{ $tag{$tag} }, $type;
        }
    }

    for my $key ( keys %{ $filter } ) {
        # Throw away bad keys
        unless ( $key ~~ [keys %$options] ) {
            delete $filter->{$key};
            next;
        }

        # Throw away bad values
        my $value = $filter->{$key};
        if ( ref($value) eq 'ARRAY' ) {
            @$value = grep { $_ ~~ $options->{$key} } @$value;
        }
        elsif ( ! ref($value) ) {
            delete $filter->{$key} unless ( $value ~~ $options->{$key} );
        }
        else {
            delete $filter->{$key};
        }

        # Convert tags to types (destructive)
        if ( $key eq 'tag' ) {
            if ( ref($value) eq 'ARRAY' ) {
                my @types;
                for my $tag ( @$value ) {
                    push @types, @{ $tag{$tag} };
                }
                my %uniq = map { $_ => 1 } @types;
                $filter->{type} = [ sort keys %uniq ];
            }
            else {
                $filter->{type} = $tag{$value};
            }
            delete $filter->{tag};
        }
    }

    return $filter;
}

sub _fleet_sort_options {
    my ($self, $sort) = @_;

    # return the default if it's not one of the following or is 'name'
    if ( ! $sort || $sort eq 'name' || ! $sort ~~ [qw(type task combat speed stealth)] ) {
        return [ 'type' ];
    }

    # append name to the sort options
    return [ "me.$sort", 'me.name' ];
}

# View all of your fleets whatever they are doing
# 
sub view_all_fleets {
    my $self = shift;
    my $args = shift;
            
    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            paging          => shift,
            filter          => shift,
            sort            => shift,
        };
    }
    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});
                                                                    
    my $paging = $self->_fleet_paging_options( (defined $args->{paging} && ref $args->{paging} eq 'HASH') ? $args->{paging} : {} );
    my $filter = $self->_fleet_filter_options( (defined $args->{filter} && ref $args->{filter} eq 'HASH') ? $args->{filter} : {} );
    my $sort = $self->_fleet_sort_options( $args->{sort} // 'type' );

    my $attrs = {
        order_by => $sort,
    };
    $attrs->{rows} = $paging->{items_per_page} if ( defined $paging->{items_per_page} );
    $attrs->{page} = $paging->{page_number} if ( defined $paging->{page_number} );

    my $body = $building->body;

    my @fleet;
    my $fleets = $body->fleets->search( $filter, $attrs );
    while (my $fleet = $fleets->next) {
        push @fleet, $fleet->get_status;
    }

    return {
        status              => $args->{no_status} ? {} : $self->format_status($empire, $body),
        number_of_fleets    => defined $paging->{page_number} ? $fleets->pager->total_entries : $fleets->count,
        fleets              => \@fleet,
    };
}

# View orbiting fleets
sub view_orbiting_fleets {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            target          => shift,
            paging          => shift,
            filter          => shift,
            sort            => shift,
        };
    }

    my $empire      = $self->get_empire_by_session($args->{session_id});
 
    my $target = $self->find_target($args->{target});
    my $fleet_rs = Lacuna->db->resultset('Fleet');
    my @ally_ids = map {$_->id} $empire->allies;
    
    $fleet_rs = $fleet_rs->search({
        task            => { in => ['Defend','Orbiting'] },
        },{
        join            => {body => 'empire'},
    });
}

# View incoming fleets (not own returning fleets)
sub view_incoming_fleets {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            target          => shift,
            paging          => shift,
            filter          => shift,
            sort            => shift,
        };
    }

    my $empire      = $self->get_empire_by_session($args->{session_id});
    # see all incoming ships from own empire, or from any alliance member
    # if the target is an allied colony, see all incoming ships dependent upon the highest
    # level of space-port on the target
    
    my $target = $self->find_target($args->{target});
    my $fleet_rs = Lacuna->db->resultset('Fleet');
    my @ally_ids = map {$_->id} $empire->allies;
    
    $fleet_rs = $fleet_rs->search({
        task            => 'Travelling',
        direction       => 'out',
        },{
        join            => 'body',
    });
    if ($target->isa('Lacuna::DB::Result::Map::Star')) {
        $fleet_rs = $fleet_rs->search({ foreign_star_id => $target->id });
    }
    else {
        $fleet_rs = $fleet_rs->search({ foreign_body_id => $target->id });
    }

    if ($target->isa('Lacuna::DB::Result::Map::Planet') and first {$_->id == $target->empire_id} @ally_ids) {
        # It is our own planet/SS or an allied one
        # so see all incoming
    }
    else {
        # otherwise only see own or allied incoming
        $fleet_rs = $fleet_rs->search({ 'body.empire_id' => \@ally_ids });
    }
    my @incoming;
    while (my $fleet = $fleet_rs->next) {
        push @incoming, $fleet->get_status;
    }
    my %out = (
        status      => $self->format_status($empire),
        incoming    => \@incoming,
    );
    return \%out;
}

#    my ($self, $session_id, $building_id, $page_number) = @_;
#
#    my $empire      = $self->get_empire_by_session($session_id);
#    my $building    = $self->get_building($empire, $building_id);
#    my $body        = $building->body;
#    my $now         = time;
#    my $alliance_id = $empire->alliance_id;
#
#    $page_number    ||= 1;
#    my @fleet;
#
#    my $fleets = $building->incoming_fleets->search({}, {
#        rows        => 25, 
#        page        => $page_number, 
#        join        => 'body',
#        prefetch    => 'body',
#        order_by    => 'date_available',
#	});
#
#    my $see_fleet_info  = ($building->level * 350) * ( $building->efficiency / 100 );
#    my $see_fleet_path  = ($building->level * 450) * ( $building->efficiency / 100 );
#    my @my_planets      = $empire->planets->get_column('id')->all;
#
#    # First tick foreign planets (once only irrespective of the number of fleets sent from there)
#    my $foreign_body;
#    # cache for foreign empires
#    my $empires;
#    while (my $fleet = $fleets->next) {
#        if ($fleet->date_available->epoch <= $now) {
#            $foreign_body->{$fleet->body_id} = $fleet;
#        }
#        $empires->{$fleet->body_id} ||= $fleet->body->empire;
#    }
#    foreach my $foreign_body_id (keys %$foreign_body) {
#        $foreign_body->{$foreign_body_id}->body->tick;
#    }
#
#
#    $fleets->reset;
#    FLEET:
#    while (my $fleet = $fleets->next) {
#        next FLEET if $fleet->date_available->epoch <= $now;
#
#        my $show_fleet_info = 0;
#        my $show_fleet_path = 0;
#        my %fleet_info = (
#            id              => $fleet->id,
#            name            => 'Unknown',
#            type_human      => 'Unknown',
#            type            => 'unknown',
#            date_arrives    => $fleet->date_available_formatted,
#            quantity        => $fleet->quantity,
#            from            => {},
#        );
#        # show all ship details if the fleet is our own or allied
#        if (    $fleet->body_id ~~ \@my_planets
#            or  $see_fleet_path >= $fleet->stealth
#            or  $alliance_id and $empires->{$fleet->body_id}->alliance_id == $alliance_id
#            ) {
#            $show_fleet_info = 1;
#            $show_fleet_path = 1;
#        }
#        # show fleet info if the space port is a high enough level
#        if ($see_fleet_path >= $fleet->stealth) {
#            $show_fleet_path = 1;
#        }
#        # see the fleet details if the space port is a high enough level
#        if ($see_fleet_info >= $fleet->stealth) {
#            $show_fleet_info = 1;
#        }
#
#        if ($see_fleet_path) {
#            $fleet_info{from} = {
#                id      => $fleet->body_id,
#                name    => $fleet->body->name,
#                empire  => {
#                    id      => $fleet->body->empire_id,
#                    name    => $empires->{$fleet->body_id}->name,
#                },
#            };
#        }
#        if ($see_fleet_info) {
#            $fleet_info{name} = $fleet->name;
#            $fleet_info{type} = $fleet->type;
#            $fleet_info{type_human} = $fleet->type_formatted;
#        }
#        push @fleet, \%fleet_info;
#    }
#    return {
#        status              => $self->format_status($empire, $building->body),
#        number_of_fleets    => $fleets->pager->total_entries,
#        fleets              => \@fleet,
#    };
#}


sub view_ships_orbiting {
    my ($self, $session_id, $building_id, $page_number) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    $page_number ||= 1;
    my @fleet;
    my $now = time;
    my $ships = $building->orbiting_ships->search({}, {rows=>25, page=>$page_number, join => 'body' });
    my $see_ship_type = ($building->level * 350) * ( $building->efficiency / 100 );
    my $see_ship_path = ($building->level * 450) * ( $building->efficiency / 100 );
    my @my_planets = $empire->planets->get_column('id')->all;
    while (my $ship = $ships->next) {
            if ($ship->date_available->epoch <= $now) {
                $ship->body->tick;
            }
            my %ship_info = (
                    id              => $ship->id,
                    name            => 'Unknown',
                    type_human      => 'Unknown',
                    type            => 'unknown',
                    date_arrived    => $ship->date_available_formatted,
                    from            => {},
                );
            if ($ship->body_id ~~ \@my_planets || $see_ship_path >= $ship->stealth) {
                $ship_info{from} = {
                    id      => $ship->body->id,
                    name    => $ship->body->name,
                    empire  => {
                        id      => $ship->body->empire->id,
                        name    => $ship->body->empire->name,
                    },
                };
                if ($ship->body_id ~~ \@my_planets || $see_ship_type >= $ship->stealth) {
                    $ship_info{name} = $ship->name;
                    $ship_info{type} = $ship->type;
                    $ship_info{type_human} = $ship->type_formatted;
                }
            }
            push @fleet, \%ship_info;
    }
    return {
        status                      => $self->format_status($empire, $building->body),
        number_of_ships             => $ships->pager->total_entries,
        ships                       => \@fleet,
    };
}

sub _view_ships {
    my ($self, $session_id, $building_id, $page_number, $method) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    my @fleet;
    my $now = time;
    my $ships = $building->$method->search({}, {rows=>25, page=>$page_number, join => 'body' });
    my $see_ship_type = ($building->level * 350) * ( $building->efficiency / 100 );
    my $see_ship_path = ($building->level * 450) * ( $building->efficiency / 100 );
    my @my_planets = $empire->planets->get_column('id')->all;
    while (my $ship = $ships->next) {
        if ($ship->date_available->epoch <= $now) {
            $ship->body->tick;
        }
        else {
            my %ship_info = (
                    id              => $ship->id,
                    name            => 'Unknown',
                    type_human      => 'Unknown',
                    type            => 'unknown',
                    date_arrives    => $ship->date_available_formatted,
                    from            => {},
                );
            if ($ship->body_id ~~ \@my_planets || $see_ship_path >= $ship->stealth) {
                $ship_info{from} = {
                    id      => $ship->body->id,
                    name    => $ship->body->name,
                    empire  => {
                        id      => $ship->body->empire->id,
                        name    => $ship->body->empire->name,
                    },
                };
                if ($ship->body_id ~~ \@my_planets || $see_ship_type >= $ship->stealth) {
                    $ship_info{name} = $ship->name;
                    $ship_info{type} = $ship->type;
                    $ship_info{type_human} = $ship->type_formatted;
                }
            }
#warn Dumper(\%ship_info); use Data::Dumper;
            push @fleet, \%ship_info;
        }
    }
    return {
        status                      => $self->format_status($empire, $building->body),
        number_of_ships             => $ships->pager->total_entries,
        ships                       => \@fleet,
    };
}

# rename some, or all, ships in a fleet
#
sub rename_fleet {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            fleet_id        => shift,
            name            => shift,
        };
    }

    Lacuna::Verify->new(content=>\$args->{name}, throws=>[1005, 'Invalid name for a fleet.'])
        ->not_empty
        ->no_profanity
        ->length_lt(31)
        ->only_ascii
        ->no_restricted_chars;

    my $name    = $args->{name};
    $name       =~ s/^\s+//;
    $name       =~ s/\s+$//;
    my $quantity = $args->{quantity};
    if (defined $quantity) {
        if ($quantity <= 0 or $quantity != int($quantity)) {
            confess [1009, "Quantity must be a positive integer."];
        }
    }
    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});
    my $fleet       = Lacuna->db->resultset('Fleet')->find($args->{fleet_id});
    if (not defined $fleet) {
        confess [1002, "Fleet not found."];
    }
    if (not defined $quantity) {
        $quantity = $fleet->quantity;
    }
    if ($quantity > $fleet->quantity) {
        confess [1009, "Quantity must be less than or equal to the number of ships in the fleet."];
    }
    if ($fleet->body_id != $building->body_id) {
        confess [1010, "You can't manage a fleet that is not yours."];
    }
    if ($quantity == $fleet->quantity) {
        $fleet->name($name);
        $fleet->update;
    }
    else {
        my $new_fleet = $fleet->split($quantity);
        if (not defined $new_fleet) {
            confess [1002, "Fleet not big enough."];
        }
        $new_fleet->name($name);
        $new_fleet->update;
    }
    return $self->view($args);
}

sub scuttle_fleet {
    my $self = shift;
    my $args = shift;
        
    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            fleet_id        => shift,
            quantity        => shift,
        };
    }
    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});

    my $fleet       = Lacuna->db->resultset('Fleet')->find($args->{fleet_id});
    if (not defined $fleet) {
        confess [1002, "Fleet not found."];
    }    
    if ($fleet->task ne 'Docked') {
        confess [1013, "You can't scuttle ships that are not docked."];
    }    
    if ($fleet->body_id != $building->body_id) {
        confess [1013, "You can't manage a fleet that is not yours."];
    }
    my $qty = $args->{quantity};
    if ($qty < 0 or int($qty) != $qty) {
        confess [1013, "Quantity of ships to delete must be a positive integer."];
    }
    if ($qty > $fleet->quantity) {
        confess [1013, "Quantity of ships to delete must be smaller than the fleet size."];
    }
    if ($qty == $fleet->quantity) {
        $fleet->delete;
    }
    else {
        $fleet->quantity($fleet->quantity - $qty);
        $fleet->update;
    }
    return $self->view($args);
}

sub view_battle_logs {
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
            paging          => shift,
            filter          => shift,
            sort            => shift,
        };
    }
    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id});

    my $paging = $self->_fleet_paging_options( (defined $args->{paging} && ref $args->{paging} eq 'HASH') ? $args->{paging} : {} );

    my $attrs = {
        order_by => { -desc => 'date_stamp' },
    };
    $attrs->{rows} = defined $paging->{items_per_page} ? $paging->{items_per_page} : 25;
    $attrs->{page} = defined $paging->{page_number} ? $paging->{page_number} : 1;

    my @logs;
    my $battle_logs = $building->battle_logs->search({}, $attrs);
    while (my $log = $battle_logs->next) {
        push @logs, {
            date                => format_date($log->date_stamp),
            attacking_empire_id => $log->attacking_empire_id,
            attacking_empire    => $log->attacking_empire_name,
            attacking_body_id   => $log->attacking_body_id,
            attacking_body      => $log->attacking_body_name,
            attacking_unit      => $log->attacking_unit_name,
            attacking_type      => $log->attacking_type,
            defending_empire_id => $log->defending_empire_id,
            defending_empire    => $log->defending_empire_name,
            defending_body_id   => $log->defending_body_id,
            defending_body      => $log->defending_body_name,
            defending_unit      => $log->defending_unit_name,
            defending_type      => $log->defending_type,
            attacked_empire_id  => $log->attacked_empire_id,
            attacked_empire     => $log->attacked_empire_name,
            attacked_body_id    => $log->attacked_body_id,
            attacked_body       => $log->attacked_body_name,
            victory_to          => $log->victory_to,
        };
    }
    return {
        status          => $self->format_status($empire, $building->body),
        number_of_logs  => $battle_logs->pager->total_entries,
        battle_log      => \@logs,
    };
}

around 'view' => sub {
    my $orig = shift;
    my $self = shift;
    my $args = shift;

    if (ref($args) ne "HASH") {
        $args = {
            session_id      => $args,
            building_id     => shift,
        };
    }
    my $empire      = $self->get_empire_by_session($args->{session_id});
    my $building    = $self->get_building($empire, $args->{building_id}, skip_offline => 1);
                                                                
    my $out         = $orig->($self, $args->{session_id}, $args->{building_id});

    return $out unless $building->level > 0;

    # TODO Replace this with a single database query and 'group by'
    my $docked = $building->body->fleets->search({ task => 'Docked' });
    my %ships;
    while (my $fleet = $docked->next) {
        $ships{$fleet->type} += $fleet->quantity;
    }
    $out->{docked_ships} = \%ships;
    $out->{max_ships} = $building->max_ships;
    $out->{docks_available} = $building->docks_available;
    return $out;
};

 
__PACKAGE__->register_rpc_method_names(qw(send_ship_types get_incoming_for view_incoming_fleets view_unavailable_fleets view_available_fleets get_fleets_for send_ship send_fleet recall_fleet recall_all recall_spies scuttle_fleet rename_fleet prepare_fetch_spies fetch_spies prepare_send_spies send_spies view_orbiting_fleets view_ships_orbiting view_fleets_travelling view_all_fleets view_battle_logs));

no Moose;
__PACKAGE__->meta->make_immutable;

