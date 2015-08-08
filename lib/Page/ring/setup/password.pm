package Page::ring::setup::password;
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

extends 'Page::ring::user';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::_log($form);
	my $content = $obj->content();
	my $user = $obj->user();
	return $obj->SUPER::load($param);
}

sub cmd_password_change
{
	my ($obj, $data, $args) = @_;
	my $orig = $data->{'pass_orig'};
	my $uid = $obj->user()->id();
	my $rc = new Note::Row(
		'ring_user' => {
			'id' => $uid,
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
			'password' => $orig,
		)) {
			my $np = $data->{'pass_1'};
			unless (length($np) >= 4)
			{
				$obj->value()->{'error'} = 'Password must be at least 4 characters';
				return;
			}
			unless ($np eq $data->{'pass_2'})
			{
				$obj->value()->{'error'} = 'Passwords do not match';
				return;
			}
			$user->password_change(
				'password' => $np,
			);
			# TODO: Clear freeswitch registration cache
			$obj->value()->{'message'} = 'Password changed';
		}
		else
		{
			$obj->value()->{'error'} = 'Incorrect current password';
			return;
		}
	}
}

1;

