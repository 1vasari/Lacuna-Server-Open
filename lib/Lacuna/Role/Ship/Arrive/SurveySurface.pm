package Lacuna::Role::Ship::Arrive::SurveySurface;

use strict;
use Moose::Role;

after handle_arrival_procedures => sub {
    my ($self) = @_;

    # we're coming home
    return if ($self->direction eq 'in');
    
    # do the scan
    my $body_attacked = $self->foreign_body;
    my @map;
    my @table = ([qw(Name Level X Y Efficiency)]);
    my $buildings = $body_attacked->buildings->search(undef,{order_by => ['x','y']});
    while (my $building = $buildings->next) {
        push @map, {
            image   => $building->image_level,
            x       => $building->x,
            y       => $building->y,
        };
        push @table, [
            $building->name,
            $building->level,
            $building->x,
            $building->y,
            $building->efficiency,
        ];
    }
    
    # phone home
    $self->body->empire->send_predefined_message(
        tags        => ['Attack','Alert'],
        filename    => 'scanner_data.txt',
        params      => [$self->type_formatted, $self->type_formatted, $self->name, $body_attacked->x, $body_attacked->y, $body_attacked->name],
        attachments  => {
            map     => {
                surface         => $body_attacked->surface,
                buildings       => \@map
            },
            table   => \@table,
        },
    );
    
    # alert empire scanned, if any
    if ($body_attacked->empire_id && defined $body_attacked->empire) {
        $body_attacked->empire->send_predefined_message(
            tags        => ['Attack','Alert'],
            filename    => 'we_were_scanned.txt',
            params      => [$body_attacked->id, $body_attacked->name, $self->type_formatted, $self->body->empire_id, $self->body->empire->name],
        );
        $body_attacked->add_news(65, sprintf('Several people reported seeing a UFO in the %s sky today.', $body_attacked->name));
    }

    my $logs = Lacuna->db->resultset('Lacuna::DB::Result::Log::Battles');
    $logs->new({
        date_stamp => DateTime->now,
        attacking_empire_id     => $self->body->empire_id,
        attacking_empire_name   => $self->body->empire->name,
        attacking_body_id       => $self->body_id,
        attacking_body_name     => $self->body->name,
        attacking_unit_name     => $self->name,
        defending_empire_id     => $body_attacked->empire_id,
        defending_empire_name   => $body_attacked->empire->name,
        defending_body_id       => $body_attacked->id,
        defending_body_name     => $body_attacked->name,
        defending_unit_name     => '',
        victory_to              => 'attacker',
    })->insert;

    # all pow
    $self->delete;
    confess [-1];
};


1;
