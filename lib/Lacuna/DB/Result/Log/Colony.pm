package Lacuna::DB::Result::Log::Colony;

use Moose;
extends 'Lacuna::DB::Result::Log';
use Lacuna::Util;

__PACKAGE__->table('colony_log');
__PACKAGE__->add_columns(
    amount                  => { data_type => 'int', size => 11, is_nullable => 0 },
    planet_id               => { data_type => 'int', size => 11, is_nullable => 0 },
    planet_name             => { data_type => 'char', size => 30, is_nullable => 0 },
    population              => { data_type => 'int', size => 11, is_nullable => 0 },
    building_count          => { data_type => 'int', size => 3, is_nullable => 0 },
    average_building_level  => { data_type => 'float', size =>[3,2] , is_nullable => 0 },
    highest_building_level  => { data_type => 'int', size => 3, is_nullable => 0 },
    lowest_building_level   => { data_type => 'int', size => 3, is_nullable => 0 },
    food_hour               => { data_type => 'int', size => 11, is_nullable => 0 },
    energy_hour             => { data_type => 'int', size => 11, is_nullable => 0 },
    waste_hour              => { data_type => 'int', size => 11, is_nullable => 0 },
    ore_hour                => { data_type => 'int', size => 11, is_nullable => 0 },
    water_hour              => { data_type => 'int', size => 11, is_nullable => 0 },
);

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
