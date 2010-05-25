package Lacuna::DB::Result::Building::Waste::Recycling;

use Moose;
extends 'Lacuna::DB::Result::Building::Waste';
use Lacuna::Util qw(to_seconds);

has max_recycle => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->level * 3_000 * $self->body->empire->species->environmental_affinity;
    },
);

has seconds_per_resource => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return 6 * $self->time_cost_reduction_bonus($self->level * 2);
    },
);

sub can_recycle {
    my ($self, $water, $ore, $energy, $use_essentia) = @_;
    $water ||= 0;
    $ore ||= 0;
    $energy ||= 0;
    if ($self->level < 1) {
        confess [1010, "You can't recycle until the Recycling Center is built."];
    }
    if ($self->is_working) {
        confess [1010, "The Recycling Center is busy."];
    }
    if (($water + $ore + $energy) > $self->body->waste_stored) {
        confess [1011, "You don't have that much waste in storage."];
    }
    if (defined $use_essentia && $use_essentia && !$self->body->empire->essentia >= 2) {
        confess [1011, "You don't have enough essentia to subsidize recycling."];
    }
    if (($water + $ore + $energy) > $self->max_recycle) {
        confess [1009, "You may only recycle ".$self->max_recycle." waste at a time."];
    }
    return 1;
}

sub recycle {
    my ($self, $water, $ore, $energy, $use_essentia) = @_;
    $self->can_recycle($water, $ore, $energy, $use_essentia);

    # setup
    my $body = $self->body;
    my $total = $water + $ore + $energy;
    
    # start
    my $seconds = $total * $self->seconds_per_resource;
    $self->start_work({
        water_from_recycling    => $water,
        ore_from_recycling      => $ore,
        energy_from_recycling   => $energy,
        }, $seconds);

    # spend
    $body->spend_waste($total);
    if ($use_essentia) {
        $body->empire->spend_essentia(2, 'recycling subsidy')->update;
        $self->finish_work;
    }
    else {
        $body->update;
        $self->update;
    }
}

before finish_work => sub {
    my $self = shift;
    my $planet = $self->body;
    $planet->add_water($self->work->{water_from_recycling});
    $planet->add_ore($self->work->{ore_from_recycling});
    $planet->add_energy($self->work->{energy_from_recycling});
    $planet->update;
};

around 'build_tags' => sub {
    my ($orig, $class) = @_;
    return ($orig->($class), qw(Water Ore));
};

use constant controller_class => 'Lacuna::RPC::Building::WasteRecycling';

use constant image => 'wasterecycling';

use constant university_prereq => 3;

use constant name => 'Waste Recycling Center';

use constant food_to_build => 75;

use constant energy_to_build => 75;

use constant ore_to_build => 70;

use constant water_to_build => 100;

use constant waste_to_build => 50;

use constant time_to_build => 280;

use constant food_consumption => 15;

use constant energy_consumption => 5;

use constant ore_consumption => 1;

use constant water_consumption => 15;



no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
