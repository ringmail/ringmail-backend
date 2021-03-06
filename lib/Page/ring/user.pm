package Page::ring::user;

use constant::boolean;
use English '-no_match_vars';
use MIME::Base64 qw{ encode_base64 };
use Moose;
use Note::Locale qw{ us_states us_state_name };
use Note::Param;
use Note::SQL::Table 'sqltable';
use Note::XML 'xml';
use POSIX 'strftime';
use Ring::User;

extends 'Note::Page';

with 'Ring::User::Admin';

has 'user' => (
    'is'  => 'rw',
    'isa' => 'Ring::User',
);

has cmdnum => (
    is      => 'rw',
    isa     => 'Maybe[Int]',
    default => sub {
        my ( $self, ) = @_;

        my ( $cmdnum, ) = map {
            do {

                my ( $cmdnum, ) = ( $ARG =~ m{ do-\d+_( \d+ ) }xms, );

                ( defined $cmdnum and $self->form()->{$ARG} eq q{} ) ? ( $cmdnum, ) : ();

            };
        } keys %{ $self->form() };

        return $cmdnum;
    },
    lazy => TRUE,
);

sub load {
    my ( @args, ) = @_;

    my ( $self, $param ) = get_param( @args, );

    my $user    = $self->user();
    my $content = $self->content();

    my $cart = sqltable('ring_cart')->get(
        select => [ qw{ rh.hashtag rh.id rc.hashtag_id rc.transaction_id }, ],
        table  => [ 'ring_cart AS rc', 'ring_hashtag AS rh', ],
        join   => 'rh.id = rc.hashtag_id',
        where  => [
            {   'rc.user_id' => $user->id(),
                'rh.user_id' => $user->id(),
            } => and => { 'rc.transaction_id' => undef, },
        ],
    );

    my $is_admin = $self->is_admin();

    $content->{cart}     = $cart;
    $content->{is_admin} = $is_admin;

    return $self->SUPER::load( $param, );
}

sub show_payment_form {
    my ( @args, ) = @_;

    my ( $obj, $param ) = get_param( @args, );
    my %months = (
        '01' => 'January',
        '02' => 'February',
        '03' => 'March',
        '04' => 'April',
        '05' => 'May',
        '06' => 'June',
        '07' => 'July',
        '08' => 'August',
        '09' => 'September',
        '10' => 'October',
        '11' => 'November',
        '12' => 'December',
    );
    my @expm = ();
    my @expy = ();
    foreach my $j ( 1 .. 12 ) {
        my $m = sprintf( "%02d", $j );
        push @expm, [ $m, $m ];
    }
    my $cur = strftime( "%Y", localtime( time() ) );
    foreach my $i ( $cur .. ( $cur + 10 ) ) {
        push @expy, [ $i, $i ];
    }
    my @sts = ();
    foreach my $st ( @{ us_states() } ) {
        push @sts, [ us_state_name($st), $st ];
    }
    my $amt     = 100;
    my $rc      = {};
    my @funding = (
        'div',
        [ {}, 'h2', [ {}, 0, 'Pay With Credit Card' ], ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'name' }, 0, 'Name:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'opts'    => { 'style' => 'width: 80px;', },
                    'name'    => 'first_name',
                    'value'   => $rc->{'first_name'},
                ),
                0,
                '&nbsp;&nbsp;',
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'opts'    => { 'style' => 'width: 110px;', },
                    'name'    => 'last_name',
                    'value'   => $rc->{'last_name'},
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'phone' }, 0, 'Phone:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'opts'    => { 'style' => 'width: 140px;', },
                    'name'    => 'phone',
                    'value'   => $rc->{'phone'},
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'address' }, 0, 'Address:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'opts'    => { 'style' => 'width: 180px;', },
                    'name'    => 'address',
                    'value'   => $rc->{'address'},
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'address2' }, 0, 'Address (2):', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'opts'    => { 'style' => 'width: 180px;', },
                    'name'    => 'address2',
                    'value'   => $rc->{'address2'},
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'city' }, 0, 'City:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'opts'    => { 'style' => 'width: 180px;', },
                    'name'    => 'city',
                    'value'   => $rc->{'city'},
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'state' }, 0, 'State:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command'  => 'fund',
                    'type'     => 'select',
                    'select'   => \@sts,
                    'selected' => $rc->{'state'},
                    'name'     => 'state',
                    'opts'     => { 'style' => 'width: 180px;', },
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'zip' }, 0, 'Zipcode:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'opts'    => { 'style' => 'width: 50px;', },
                    'name'    => 'zip',
                    'value'   => $rc->{'zip'},
                ),
            ],
        ],
        'div',
        [ { 'style' => 'text-align: center;' }, 'h5', [ {}, 0, 'Card Details' ], ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'cc_type' }, 0, 'Type of Card:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'select',
                    'name'    => 'cc_type',
                    'select'  => [ [ 'Visa', 'Visa' ], [ 'MasterCard', 'MasterCard' ], [ 'American Express', 'AMEX' ], [ 'Discover', 'Discover' ], ],
                    'opts' => { 'style' => 'width: 180px;', },
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'cc_num' }, 0, 'Card Number:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'name'    => 'cc_num',
                    'opts'    => { 'style' => 'width: 160px;', },
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'cc_exp' }, 0, 'Card Expires:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'select',
                    'name'    => 'cc_expm',
                    'select'  => \@expm,
                    'opts'    => { 'style' => 'width: 60px;', },
                ),
                0,
                '&nbsp;&nbsp;',
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'select',
                    'name'    => 'cc_expy',
                    'select'  => \@expy,
                    'opts'    => { 'style' => 'width: 90px;', },
                ),
            ],
        ],
        'div',
        [   { 'class' => 'control-group' },
            'label',
            [ { 'class' => 'control-label', 'for' => 'cc_code' }, 0, 'Security Code:', ],
            'div',
            [   { 'class' => 'controls' },
                0,
                $obj->field(
                    'command' => 'fund',
                    'type'    => 'text',
                    'name'    => 'cc_cvv2',
                    'opts'    => { 'style' => 'width: 50px;', },
                ),
            ],
        ],
        'div',
        [   { 'style' => 'padding-left: 180px;', 'class' => 'form-actions' },
            0,
            $obj->button(
                'text' => xml( 'i', [ {}, 0, '' ], 0, 'Make Payment', ),
                'command' => 'fund',
                'opts'    => { 'class' => 'btn btn-large btn-info', },
            ),
        ],
    );
    return xml(@funding);
}

sub valid_user {
    my ($obj) = @_;
    my $sd = $obj->session();
    if ( defined $sd->{'login_ringmail'} ) {
        my $user = Ring::User->new( $sd->{'login_ringmail'} );
        my $urc = Note::Row->new( 'ring_user' => $user->{'id'} );
        if ( $urc->data('active') ) {
            $obj->user($user);
            return 1;
        }
    }
    $obj->redirect( $obj->url( 'path' => '/login' ) );
    return 0;
}

sub cmd_logout {
    my ( $self, ) = @_;

    my $sd = $self->session();

    if ( $sd->{login_ringmail_original} ) {

        $sd->{login_ringmail} = $sd->{login_ringmail_original};

        delete $sd->{login_ringmail_original};
        $self->session_write();
        $self->redirect( $self->url( path => '/u', ), );

    }
    else {

        delete $sd->{login_ringmail};
        $self->session_write();
        $self->redirect( $self->url( path => '/', ), );

    }

    return;
}

1;
