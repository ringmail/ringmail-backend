package Page::ring::fsconfig;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use POSIX 'strftime';
use URI::Encode 'uri_decode', 'uri_encode';
use Digest::MD5 'md5_hex';

use Note::XML 'xml';
use Note::Page;;
use Note::Param;

use base 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::_log($form);
	my $res = '';
	my $ok = 0;
	if ($form->{'sip_auth_method'} eq 'REGISTER' || $form->{'sip_auth_method'} eq 'INVITE')
	{
		#my $login = uri_decode($form->{'sip_auth_username'});
		my $login = $form->{'sip_auth_username'};
		$login =~ s/\%40/\@/;
		my $realm = $form->{'sip_auth_realm'};
		my $dom = $form->{'domain'};
		my @prm = ();
		if ($login =~ /^(.*)\@/)
		{
			#$login .= '@'. $1;
			my $prec = new Note::Row(
				'ring_user' => {
					'login' => $login,
					'active' => 1,
				},
				{
					'select' => [qw/password_fs/],
				},
			);
			if ($prec->id())
			{
				$ok = 1;
				$login = $form->{'sip_auth_username'};
				#my $lh = "$login:$realm:test";
				#::_log("H1: $lh");
				#my $h = md5_hex($lh);
				my $h = $prec->data('password_fs');
				#::_log("H2: $h");
				@prm = (
					'param', [{'name' => 'a1-hash', 'value' => $h}],
					'param', [{'name' => 'sip-force-user', 'value' => "u_". $prec->id()}],
				);
			}
		}
#		elsif ($login =~ /\@/)
#		{
#			my $prec = new Note::Row(
#				'ring_user' => {
#					'login' => $login,
#					'active' => 1,
#				},
#			);
#			if ($prec->id())
#			{
#				$ok = 1;
#				my $lh = "$login:$realm:test";
#				::_log("H2: $lh");
#				my $h = md5_hex($lh);
#				@prm = (
#					'param', [{'name' => 'a1-hash', 'value' => $h}],
#				);
#			}
#		}
		unless ($ok)
		{
			my $prec = new Note::Row(
				'ring_phone' => {
					'login' => $login,
				},
				{
					'select' => [qw/password/],
				},
			);
			if ($prec->id())
			{
				$ok = 1;
				@prm = (
					'param', [{'name' => 'password', 'value' => $prec->data('password')}],
				);
			}
		}
		if ($ok)
		{
			$obj->response()->content_type('text/xml');
			$res = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>';
			$res .= "\n";
			$res .= xml(
				'document', [{'type' => 'freeswitch/xml'},
					'section', [{'name' => 'directory'},
						'domain', [{'name' => $dom},
							'params', [{},
								'param', [{'name' => 'dial-string', 'value' => '${sofia_contact(${dialed_user}@${dialed_domain})}'}],
							],
							'groups', [{},
								'group', [{'name' => 'default'},
									'users', [{},
										'user', [{'id' => $login, 'cacheable' => 'true'},
											'params', [{},
												@prm,
											],
										],
									],
								],
							],
						],
					],
				],
			);
		}
	}
	elsif ($form->{'Event-Name'} eq 'GENERAL' && $form->{'action'} eq 'message-count')
	{
		$ok = 1;
		$obj->response()->content_type('text/xml');
		$res = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>';
		$res .= "\n";
		$res .= xml(
			'document', [{'type' => 'freeswitch/xml'},
				'section', [{'name' => 'result'},
					'result', [{'status' => 'not found'}],
				],
			],
		);
	}
	unless ($ok)
	{
		#$obj->response()->status(404);
		$obj->response()->content_type('text/xml');
		$res = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>';
		$res .= "\n";
		$res .= xml(
			'document', [{'type' => 'freeswitch/xml'},
				'section', [{'name' => 'result'},
					'result', [{'status' => 'not found'}],
				],
			],
		);
	}
	#::_log($res);
	return $res;
}

1;

