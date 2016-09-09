package Page::ring::signup;

use Data::Validate::Domain 'is_domain';
use Email::Valid;
use HTML::Entities 'encode_entities';
use JSON::XS 'encode_json';
use Moose;
use Note::Param;
use Ring::API;
use Ring::User;

extends 'Note::Page';

sub register {
    my ( $obj, $data, $args ) = @_;
    my $form = $obj->form();
    my $ct   = $obj->content();
    my $val  = $obj->value();

    #my $type = $data->{'type'};
    my $type = 'email';
    my @errs = ();
    my $rec  = {};
    $data->{'route_phone'} =~ s/\D//gxms;
    if ( length( $data->{'route_phone'} ) ) {
        if ( length( $data->{'route_phone'} ) == 11 && $data->{'route_phone'} =~ /^1/xms ) {
            $data->{'route_phone'} =~ s/^1//xms;
            $rec->{'route_phone'} = $data->{'route_phone'};
        }
        elsif ( length( $data->{'route_phone'} ) == 10 ) {
            $rec->{'route_phone'} = $data->{'route_phone'};
        }
        else {
            $val->{'error'}->{'route_phone'} = 1;
            push @errs, 'Not a 10-digit US phone number';
        }
    }
    if ( not length( $data->{'password'} ) >= 4 ) {
        $val->{'error'}->{'password'} = 1;
        push @errs, 'Password must be at least 4 characters long';
    }
    if ( $type eq 'email' ) {
        $rec->{'type_email'} = 1;
        $data->{'target_email'} =~ s/^\s+//gxms;
        $data->{'target_email'} =~ s/\s+$//gxms;
        if ( Email::Valid->address( $data->{'target_email'} ) ) {
            $rec->{'target_email'} = $data->{'target_email'};
            my $ck = Ring::API->cmd(
                'path' => [ 'user', 'check', 'user' ],
                'data' => {
                    'email' => $rec->{'target_email'},
                    ( ( defined $rec->{'route_phone'} ) ? ( 'phone' => $rec->{'route_phone'} ) : () ),
                },
            );
            unless ( $ck->{'ok'} ) {
                $val->{'error'}->{'target_email'} = 1;
                if ( defined $rec->{'route_phone'} ) {
                    $val->{'error'}->{'route_phone'} = 1;
                }
                push @errs, $ck->{'error'};
            }
        }
        else {
            $val->{'error'}->{'target_email'} = 1;
            push @errs, 'Invalid email address';
        }
    }
    elsif ( $type eq 'domain' ) {
        $rec->{'type_domain'} = 1;
        $data->{'target_domain'} =~ s/^\s+//gxms;
        $data->{'target_domain'} =~ s/\s+$//gxms;
        $data->{'target_domain'} = lc( $data->{'target_domain'} );
        $data->{'login_email'} =~ s/^\s+//gxms;
        $data->{'login_email'} =~ s/\s+$//gxms;
        if ( is_domain( $data->{'target_domain'} ) ) {
            $rec->{'target_domain'} = $data->{'target_domain'};
            my $ck = Ring::API->cmd(
                'path' => [ 'user', 'check', 'domain' ],
                'data' => { 'domain' => $rec->{'target_domain'}, },
            );
            unless ( $ck->{'ok'} ) {
                $val->{'error'}->{'target_domain'} = 1;
                push @errs, $ck->{'error'};
            }
        }
        else {
            $val->{'error'}->{'target_domain'} = 1;
            push @errs, 'Invalid domain name';
        }
        if ( Email::Valid->address( $data->{'login_email'} ) ) {
            $rec->{'login_email'} = $data->{'login_email'};
            unless ( scalar @errs ) {
                my $ck = Ring::API->cmd(
                    'path' => [ 'user', 'check', 'user' ],
                    'data' => { 'email' => $rec->{'login_email'}, },
                );
                unless ( $ck->{'ok'} ) {
                    $val->{'error'}->{'login_email'} = 1;
                    push @errs, $ck->{'error'};
                }
            }
        }
        else {
            $val->{'error'}->{'login_email'} = 1;
            push @errs, 'Invalid email address';
        }
    }
    else {
        $ct->{'error'} = 'Invalid type';
        return;
    }
    if ( scalar @errs ) {
        %{$val} = ( %{$val}, %{$rec} );
        $ct->{'error'} = join '<br/>', @errs;
        return;
    }
    if ( $type eq 'email' ) {
        my $mkuser = Ring::API->cmd(
            'path' => [ 'user', 'create' ],
            'data' => {
                'email' => $rec->{'target_email'},
                ( ( defined $rec->{'route_phone'} ) ? ( 'phone' => $rec->{'route_phone'} ) : () ),
                'password'  => $data->{'password'},
                'password2' => $data->{'password'},
            },
        );
        if ( $mkuser->{'ok'} ) {

            #			if (defined $rec->{'route_phone'})
            #			{
            #				my $ph = Ring::API->cmd(
            #					'path' => ['user', 'target', 'list', 'email'],
            #					'data' => {
            #						'user_id' => $mkuser->{'user_id'},
            #						'email' => $rec->{'target_email'},
            #					},
            #				);
            #				if ($ph->{'ok'})
            #				{
            #					my $item = $ph->{'list'}->[0];
            #					my $did = Ring::API->cmd(
            #						'path' => ['user', 'endpoint', 'add', 'did'],
            #						'data' => {
            #							'user_id' => $mkuser->{'user_id'},
            #							'did' => $rec->{'route_phone'},
            #						},
            #					);
            #					if ($did->{'ok'})
            #					{
            #						my $setrt = Ring::API->cmd(
            #							'path' => ['user', 'endpoint', 'select'],
            #							'data' => {
            #								'user_id' => $mkuser->{'user_id'},
            #								'target_id' => $item->{'target_id'},
            #								'endpoint_type' => 'did',
            #								'endpoint_id' => $did->{'endpoint_id'},
            #							},
            #						);
            #						unless ($setrt->{'ok'})
            #						{
            #							::_log("Error selecting endpoint", $setrt, $did, $item);
            #						}
            #					}
            #					else
            #					{
            #						::_log("Error adding endpoint", $did);
            #					}
            #				}
            #			}
            $obj->session()->{'signup_user'} = $mkuser->{'user_id'};
            $obj->session_write();
            $obj->redirect( $obj->url( 'path' => '/signup-done' ) );
        }
        else {
            $ct->{'error'} = 'An error occurred creating user account';
            ::_log( "Create User Error", $mkuser->{'errors'}->[2]->{'error'} );
            return;
        }
    }
    elsif ( $type eq 'domain' ) {
        my $mkuser = Ring::API->cmd(
            'path' => [ 'user', 'create' ],
            'data' => {
                'email'     => $rec->{'login_email'},
                'password'  => $data->{'password'},
                'password2' => $data->{'password'},
            },
        );
        if ( $mkuser->{'ok'} ) {
            my $dok = Ring::API->cmd(
                'path' => [ 'user', 'target', 'verify', 'domain', 'generate' ],
                'data' => {
                    'user_id' => $mkuser->{'user_id'},
                    'domain'  => $rec->{'target_domain'},
                },
            );
            unless ( $dok->{'ok'} ) {
                $ct->{'error'} = 'An error occurred adding domain name to user account';
                ::_log( "Create User Domain Error", $dok, $mkuser );
            }
            $obj->session()->{'signup_user'} = $mkuser->{'user_id'};
            $obj->session_write();
            $obj->redirect( $obj->url( 'path' => '/signup-done' ) );
        }
        else {
            $ct->{'error'} = 'An error occurred creating user account';
            ::_log( "Create User Error", $mkuser );
            return;
        }
    }

    return;
}

1;
