package Page::ring::login;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;

use Ring::User;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	if (exists $form->{'login'})
	{
		my $rc = new Note::Row(
			'ring_user' => {
				'login' => $form->{'login'},
			},
			{
				'select' => [qw/password_salt password_hash/],
			},
		);
		my $ok = 0;
		if ($rc->id())
		{
			my $user = new Ring::User($rc->id());
			if ($user->check_password(
				'salt' => $rc->data('password_salt'),
				'hash' => $rc->data('password_hash'),
				'password' => $form->{'password'},
			)) {
				my $sd = $obj->session();
				$sd->{'login_ringmail'} = $rc->id();
				$obj->session_write();
				$obj->redirect($obj->url('path' => '/u'));
				return;
			}
		}
		$content->{'error'} = xml(
			'strong', [{}, 0, 'Error: '],
			0, 'Invalid email or password.',
		);
	}
	return $obj->SUPER::load($param);
}

1;

