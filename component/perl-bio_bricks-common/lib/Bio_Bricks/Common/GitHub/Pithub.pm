package Bio_Bricks::Common::GitHub::Pithub;
# ABSTRACT: Pithub subclass with automatic GitHub authentication

use Bio_Bricks::Common::Setup;

extends 'Pithub';

with qw(Bio_Bricks::Common::GitHub::Pithub::Role::Authable);

1;
