package Ring::Model::Template;

use strict;
use warnings;

use open ':encoding(UTF-8)';

use Moose;
use Carp 'croak';
use English '-no_match_vars';
use JSON::XS qw{ decode_json };

has caller => ( is => 'ro', isa => 'Any', );

sub list {
    my ( $self, ) = @_;

    my $caller = $self->caller();

    my $filename = $caller->root() . '/data/template/templates.json';

    open my $filehandle, '<', $filename or croak $OS_ERROR;
    local $RS = undef;
    my $data = decode_json readline $filehandle;
    close $filehandle or croak $OS_ERROR;

    return $data;
}

1;
