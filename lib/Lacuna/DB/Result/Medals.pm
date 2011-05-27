package Lacuna::DB::Result::Medals;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::DB::Result';
use Lacuna::Util qw(format_date);
use DateTime;

__PACKAGE__->table('medals');
__PACKAGE__->add_columns(
    type                    => { data_type => 'varchar', size => 30, is_nullable => 0 },
    empire_id               => { data_type => 'int', size => 11, is_nullable => 0 },
    public                  => { data_type => 'bit', default_value => 1 },
    datestamp               => { data_type => 'datetime', is_nullable => 0, set_on_create => 1 },
    times_earned            => { data_type => 'int', size => 11, default_value => 1 },
);

__PACKAGE__->belongs_to('empire', 'Lacuna::DB::Result::Empire', 'empire_id');

sub format_datestamp {
    my ($self) = @_;
    return format_date($self->datestamp);
}

use constant MEDALS => {
    supply_pod                      => 'Built Supply Pod',
    supply_pod2                     => 'Built Supply Pod II',
    supply_pod3                     => 'Built Supply Pod III',
    supply_pod4                     => 'Built Supply Pod IV',
    probe                           => 'Built Probe',
    short_range_colony_ship         => 'Built Short Range Colony Ship',
    colony_ship                     => 'Built Colony Ship',
    spy_pod                         => 'Built Spy Pod',
    cargo_ship                      => 'Built Cargo Ship',
    space_station                   => 'Built Space Station Hull',
    smuggler_ship                   => 'Built Smuggler Ship',
    mining_platform_ship            => 'Built Mining Platform Ship',
    terraforming_platform_ship      => 'Built Terraforming Platform Ship',
    gas_giant_settlement_ship       => 'Built Gas Giant Settlement Platform Ship',
    scow                            => 'Built Scow',
    dory                            => 'Built Dory',
    barge                           => 'Built Barge',
    placebo                         => 'Built Placebo',
    placebo2                        => 'Built Placebo II',
    placebo3                        => 'Built Placebo III',
    placebo4                        => 'Built Placebo IV',
    placebo5                        => 'Built Placebo V',
    placebo6                        => 'Built Placebo VI',
    bleeder                         => 'Built Bleeder',
    galleon                         => 'Built Galleon',
    hulk                            => 'Built Hulk',
    freighter                       => 'Built Freighter',
    thud                            => 'Built Thud',
    stake                           => 'Built Stake',
    sweeper                         => 'Built Sweeper',
    snark                           => 'Built Snark',
    snark2                          => 'Built Snark II',
    snark3                          => 'Built Snark III',
    drone                           => 'Built Drone',
    fighter                         => 'Built Fighter',
    spy_shuttle                     => 'Built Spy Shuttle',
    observatory_seeker              => 'Built Observatory Seeker',
    security_ministry_seeker        => 'Built Security Ministry Seeker',
    spaceport_seeker                => 'Built SpacePort Seeker',
    excavator                       => 'Built Excavator',
    detonator                       => 'Built Detonator',
    scanner                         => 'Built Scanner',
    surveyor                        => 'Built Surveyor',
    rutile_glyph                    => 'Uncovered Rutile Glyph',
    chromite_glyph                  => 'Uncovered Chromite Glyph',
    chalcopyrite_glyph              => 'Uncovered Chalcopyrite Glyph',
    galena_glyph                    => 'Uncovered Galena Glyph',
    gold_glyph                      => 'Uncovered Gold Glyph',
    uraninite_glyph                 => 'Uncovered Uraninite Glyph',
    bauxite_glyph                   => 'Uncovered Bauxite Glyph',
    goethite_glyph                  => 'Uncovered Goethite Glyph',
    halite_glyph                    => 'Uncovered Halite Glyph',
    gypsum_glyph                    => 'Uncovered Gypsum Glyph',
    trona_glyph                     => 'Uncovered Trona Glyph',
    kerogen_glyph                   => 'Uncovered Kerogen Glyph',
    methane_glyph                   => 'Uncovered Methane Glyph',
    anthracite_glyph                => 'Uncovered Anthracite Glyph',
    sulfur_glyph                    => 'Uncovered Sulfur Glyph',
    zircon_glyph                    => 'Uncovered Zircon Glyph',
    monazite_glyph                  => 'Uncovered Monazite Glyph',
    fluorite_glyph                  => 'Uncovered Fluorite Glyph',
    beryl_glyph                     => 'Uncovered Beryl Glyph',
    magnetite_glyph                 => 'Uncovered Magnetite Glyph',
    largest_colony                  => 'Largest Colony',
    fastest_growing_colony          => 'Fastest Growing Colony',
    largest_empire                  => 'Largest Empire',
    fastest_growing_empire          => 'Fastest Growing Empire',
    dirtiest_empire_in_the_game     => 'Dirtiest Empire In The Game',
    dirtiest_empire_of_the_week     => 'Dirtiest Empire Of The Week',
    best_defender_of_the_week       => 'Best Defender Of The Week',
    best_defender_in_the_game       => 'Best Defender In The Game',
    best_attacker_of_the_week       => 'Best Attacker Of The Week',
    best_attacker_in_the_game       => 'Best Attacker In The Game',
    most_improved_spy_of_the_week   => 'Most Improved Spy Of The Week',
    dirtiest_spy_in_the_game        => 'Dirtiest Spy In The Game',
    dirtiest_spy_of_the_week        => 'Dirtiest Spy Of The Week',
    best_defensive_spy_of_the_week  => 'Best Defensive Spy Of The Week',
    best_defensive_spy_in_the_game  => 'Best Defensive Spy In The Game',
    best_offensive_spy_of_the_week  => 'Best Offensive Spy Of The Week',
    best_offensive_spy_in_the_game  => 'Best Offensive Spy In The Game',
    best_spy_of_the_week            => 'Best Spy Of The Week',
    best_spy_in_the_game            => 'Best Spy In The Game',
    pleased_to_meet_you             => 'Meeting the Lacunans',
    P1                              => 'Settled P1 Type Planet',  
    P2                              => 'Settled P2 Type Planet',  
    P3                              => 'Settled P3 Type Planet',  
    P4                              => 'Settled P4 Type Planet',  
    P5                              => 'Settled P5 Type Planet',  
    P6                              => 'Settled P6 Type Planet',  
    P7                              => 'Settled P7 Type Planet',  
    P8                              => 'Settled P8 Type Planet',  
    P9                              => 'Settled P9 Type Planet',  
    P10                             => 'Settled P10 Type Planet',  
    P11                             => 'Settled P11 Type Planet',  
    P12                             => 'Settled P12 Type Planet',  
    P13                             => 'Settled P13 Type Planet',  
    P14                             => 'Settled P14 Type Planet',  
    P15                             => 'Settled P15 Type Planet',  
    P16                             => 'Settled P16 Type Planet',  
    P17                             => 'Settled P17 Type Planet',  
    P18                             => 'Settled P18 Type Planet',  
    P19                             => 'Settled P19 Type Planet',  
    P20                             => 'Settled P20 Type Planet',  
    G1                              => 'Settled G1 Type Gas Giant',  
    G2                              => 'Settled G2 Type Gas Giant',  
    G3                              => 'Settled G3 Type Gas Giant',  
    G4                              => 'Settled G4 Type Gas Giant',  
    G5                              => 'Settled G5 Type Gas Giant', 
    Station                         => 'Established a Space Station',
    A1                              => 'Mined A1 Type Asteroid',
    A2                              => 'Mined A2 Type Asteroid',
    A3                              => 'Mined A3 Type Asteroid',
    A4                              => 'Mined A4 Type Asteroid',
    A5                              => 'Mined A5 Type Asteroid',
    A6                              => 'Mined A6 Type Asteroid',
    A7                              => 'Mined A7 Type Asteroid',
    A8                              => 'Mined A8 Type Asteroid',
    A9                              => 'Mined A9 Type Asteroid',
    A10                             => 'Mined A10 Type Asteroid',
    A11                             => 'Mined A11 Type Asteroid',
    A12                             => 'Mined A12 Type Asteroid',
    A13                             => 'Mined A13 Type Asteroid',
    A14                             => 'Mined A14 Type Asteroid',
    A15                             => 'Mined A15 Type Asteroid',
    A16                             => 'Mined A16 Type Asteroid',
    A17                             => 'Mined A17 Type Asteroid',
    A18                             => 'Mined A18 Type Asteroid',
    A19                             => 'Mined A19 Type Asteroid',
    A20                             => 'Mined A20 Type Asteroid',
    A21                             => 'Mined Debris Field',
    building1                       => 'Built Level 1 Building',
    building2                       => 'Built Level 2 Building',
    building3                       => 'Built Level 3 Building',
    building4                       => 'Built Level 4 Building',
    building5                       => 'Built Level 5 Building',
    building6                       => 'Built Level 6 Building',
    building7                       => 'Built Level 7 Building',
    building8                       => 'Built Level 8 Building',
    building9                       => 'Built Level 9 Building',
    building10                      => 'Built Level 10 Building',
    building11                      => 'Built Level 11 Building',
    building12                      => 'Built Level 12 Building',
    building13                      => 'Built Level 13 Building',
    building14                      => 'Built Level 14 Building',
    building15                      => 'Built Level 15 Building',
    building16                      => 'Built Level 16 Building',
    building17                      => 'Built Level 17 Building',
    building18                      => 'Built Level 18 Building',
    building19                      => 'Built Level 19 Building',
    building20                      => 'Built Level 20 Building',
    building21                      => 'Built Level 21 Building',
    building22                      => 'Built Level 22 Building',
    building23                      => 'Built Level 23 Building',
    building24                      => 'Built Level 24 Building',
    building25                      => 'Built Level 25 Building',
    building26                      => 'Built Level 26 Building',
    building27                      => 'Built Level 27 Building',
    building28                      => 'Built Level 28 Building',
    building29                      => 'Built Level 29 Building',
    building30                      => 'Built Level 30 Building',
    SAW                             => 'Built Shield Against Weapons',
    OperaHouse                      => 'Installed Opera House',
    ArtMuseum                       => 'Installed Art Museum',
    CulinaryInstitute               => 'Installed Culinary Institute',
    IBS                             => 'Installed Interstellar Broadcast System',
    StationCommand                  => 'Installed Station Command Center',
    Parliament                      => 'Installed Parliament',
    Warehouse                       => 'Installed Warehouse',
    DistributionCenter              => 'Built Distribution Center',
    AtmosphericEvaporator           => 'Built Atmospheric Evaporator',
    GreatBallOfJunk                 => 'Built Great Ball of Junk',
    PyramidJunkSculpture            => 'Built Pyramid Junk Sculpture',
    SpaceJunkPark                   => 'Built Space Junk Park',
    MetalJunkArches                 => 'Built Metal Junk Arches',
    JunkHengeSculpture              => 'Built Junk Henge Sculpture',
    Capitol                         => 'Built Capitol',
    ThemePark                       => 'Built Theme Park',
    BlackHoleGenerator              => 'Discovered a Black Hole Generator',
    HallsOfVrbansk                  => 'Discovered the Halls of Vrbansk',
    GratchsGauntlet                 => 'Discovered Gratch\'s Gauntlet',
    KasternsKeep                    => 'Discovered Kastern\'s Keep',
    TheDillonForge                  => 'Discovered the Dillon Forge',
    SupplyPod                       => 'Received Supply Pod',
    SubspaceSupplyDepot             => 'Received Subspace Supply Depot',
    Stockpile                       => 'Built Stockpile',
    Algae                           => 'Built Algae Cropper',
    Apple                           => 'Built Apple Orchard',
    Bean                            => 'Built Bean Plantation',
    Beeldeban                       => 'Built Beeldeban Herder',
    Bread                           => 'Built Bakery',
    Burger                          => 'Built Burger Factory',
    Cheese                          => 'Built Cheese Factory',
    Chip                            => 'Built Chip Frier',
    Cider                           => 'Built Cider Bottler',
    Corn                            => 'Built Corn Plantation',
    CornMeal                        => 'Built Corn Meal Grinder',
    Lagoon                          => 'Discovered a Lagoon',
    Sand                            => 'Discovered a Patch of Sand',
    Grove                           => 'Discovered a Grove of Trees',
    Crater                          => 'Discovered a Crater',
    DeployedBleeder                 => 'Deployed a Bleeder',
    Dairy                           => 'Built Dairy Farm',
    Denton                          => 'Built Denton Root Farm',
    Development                     => 'Built Development Ministry',
    Embassy                         => 'Built Embassy',
    EnergyReserve                   => 'Built Energy Reserve',
    Entertainment                   => 'Built Entertainment District',
    Espionage                       => 'Built Espionage Ministry',
    LCOTa                           => 'Discovered Lost City of Tyleon (A)',
    LCOTb                           => 'Discovered Lost City of Tyleon (B)',
    LCOTc                           => 'Discovered Lost City of Tyleon (C)',
    LCOTd                           => 'Discovered Lost City of Tyleon (D)',
    LCOTe                           => 'Discovered Lost City of Tyleon (E)',
    LCOTf                           => 'Discovered Lost City of Tyleon (F)',
    LCOTg                           => 'Discovered Lost City of Tyleon (G)',
    LCOTh                           => 'Discovered Lost City of Tyleon (H)',
    LCOTi                           => 'Discovered Lost City of Tyleon (I)',
    SSLa                            => 'Built Space Station Lab (A)',
    SSLb                            => 'Built Space Station Lab (B)',
    SSLc                            => 'Built Space Station Lab (C)',
    SSLd                            => 'Built Space Station Lab (D)',
    MalcudField                     => 'Discovered a Malcud Field',
    Ravine                          => 'Discovered a Ravine',
    AlgaePond                       => 'Discovered a Algae Pond',
    LapisForest                     => 'Discovered a Lapis Forest',
    BeeldebanNest                   => 'Discovered a Beeldeban Nest',
    CrashedShipSite                 => 'Discovered a Crashed Ship Site',
    CitadelOfKnope                  => 'Discovered the Citadel of Knope',
    KalavianRuins                   => 'Discovered the Kalavian Ruins',
    MassadsHenge                    => 'Discovered Massad\'s Henge',
    PantheonOfHagness               => 'Discovered the Pantheon of Hagness',
    Volcano                         => 'Discovered a Volcano',
    TempleOfTheDrajilites           => 'Discovered the Temple of the Drajilites',
    GeoThermalVent                  => 'Discovered a Geo Thermal Vent',
    OracleOfAnid                    => 'Discovered the Oracle of Anid',
    InterDimensionalRift            => 'Discovered an Interdimensional Rift',
    NaturalSpring                   => 'Discovered a Natural Spring',
    LibraryOfJith                   => 'Discovered the Library of Jith',
    EssentiaVein                    => 'Discovered a vein of Essentia',
    Fission                         => 'Built Fission Reactor',
    FoodReserve                     => 'Built Food Reserve',
    Fusion                          => 'Built Fusion Reactor',
    GasGiantLab                     => 'Built Gas Giant Lab',
    GasGiantPlatform                => 'Built Gas Giant Platform',
    Geo                             => 'Built Geo Energy Plant',
    Hydrocarbon                     => 'Built Hydrocarbon Energy Plant',
    Intelligence                    => 'Built Intelligence Ministry',
    IntelTraining                   => 'Built Intel Training Facility',
    Lapis                           => 'Built Lapis Orchard',
    Lake                            => 'Discovered a Lake',
    Malcud                          => 'Built Malcud Fungus Farm',
    MayhemTraining                  => 'Built Mayhem Training Facility',
    Mine                            => 'Built Mine',
    MiningMinistry                  => 'Built Mining Ministry',
    MiningPlatform                  => 'Built Mining Platform',
    Network19                       => 'Built Network 19 Affiliate',
    Observatory                     => 'Built Observatory',
    OreRefinery                     => 'Built Ore Refinery',
    OreStorage                      => 'Built Ore Storage Tank',
    Pancake                         => 'Built Pancake Factory',
    Park                            => 'Built Park',
    Pie                             => 'Built Pie Factory',
    PlanetaryCommand                => 'Built Planetary Command Center',
    PoliticsTraining                => 'Built Politics Training Facility',
    Potato                          => 'Built Potato Plantation',
    Propulsion                      => 'Built Propulsion Factory',
    Oversight                       => 'Built Oversight Ministry',
    RockyOutcrop                    => 'Discovered a Rocky Outcropping',
    Security                        => 'Built Security Ministry',
    Shake                           => 'Built Shake Factory',
    Shipyard                        => 'Built Shipyard',
    Singularity                     => 'Built Singularity Energy Plant',
    Soup                            => 'Built Soup Cannery',
    SpacePort                       => 'Built Space Port',
    Syrup                           => 'Built Syrup Bottler',
    TerraformingLab                 => 'Built Terraforming Lab',
    GeneticsLab                     => 'Built Genetics Lab',
    Archaeology                     => 'Built Archaeology Ministry',
    TerraformingPlatform            => 'Built Terraforming Platform',
    TheftTraining                   => 'Built Theft Training Facility',
    Trade                           => 'Built Trade Ministry',
    Transporter                     => 'Built Subspace Transporter',
    University                      => 'Built University',
    WasteEnergy                     => 'Built Waste Energy Plant',
    WasteExchanger                  => 'Built Waste Exchanger',
    WasteRecycling                  => 'Built Waste Recycling Center',
    WasteSequestration              => 'Built Waste Sequestration Well', 
    WasteDigester                   => 'Built Waste Digester',
    WasteTreatment                  => 'Built Waste Treatment Center',
    WaterProduction                 => 'Built Water Production Plant',
    WaterPurification               => 'Built Water Purification Plant',
    WaterReclamation                => 'Built Water Reclamation Plant',
    WaterStorage                    => 'Built Water Storage Tank',
    Wheat                           => 'Built Wheat Farm',
    Beach1                          => 'Built Beach (section 1)',
    Beach2                          => 'Built Beach (section 2)',
    Beach3                          => 'Built Beach (section 3)',
    Beach4                          => 'Built Beach (section 4)',
    Beach5                          => 'Built Beach (section 5)',
    Beach6                          => 'Built Beach (section 6)',
    Beach7                          => 'Built Beach (section 7)',
    Beach8                          => 'Built Beach (section 8)',
    Beach9                          => 'Built Beach (section 9)',
    Beach10                         => 'Built Beach (section 10)',
    Beach11                         => 'Built Beach (section 11)',
    Beach12                         => 'Built Beach (section 12)',
    Beach13                         => 'Built Beach (section 13)',
    MunitionsLab                    => 'Built Munitions Lab',
    PilotTraining                   => 'Built Pilot Training Facility',
    LuxuryHousing                   => 'Built Luxury Housing',
    MissionCommand                  => 'Built Mission Command',
    CloakingLab                     => 'Built Cloaking Lab',
    AmalgusMeadow                   => 'Discovered an Amalgus Meadow',
    DentonBrambles                  => 'Discovered Denton Brambles',
    MercenariesGuild                => 'Built Mercenaries Guild',
    PoliceStation                   => 'Built Police Station',
};

sub name {
    my $self = shift;
    return MEDALS->{$self->type};
}

sub image {
    my $self = shift;
    return $self->type;
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
