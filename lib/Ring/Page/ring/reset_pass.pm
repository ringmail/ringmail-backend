package Page::ring::reset_pass;
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
	if (exists($form->{'code'}) && length($form->{'code'}) == 32)
	{
		my $rc = new Note::Row(
			'ring_user_pwreset' => {
				'reset_hash' => $form->{'code'},
			},
			{
				'select' => [qw/user_id/],
			},
		);
		if ($rc->id())
		{
			my $done = 0;
			if (length($form->{'pass1'}))
			{
				if (length($form->{'pass1'}) >= 4)
				{
					if ($form->{'pass1'} eq $form->{'pass2'})
					{
						my $user = new Ring::User($rc->data('user_id'));
						$user->password_change('password' => $form->{'pass1'});
						$rc->delete();
						$content->{'message'} = xml(
							'strong', [{}, 0, 'Password Updated: '],
							0, 'Your RingMail password has been updated.',
						);
						my $urec = new Note::Row('ring_user' => {'id' => $user->id()});
						$content->{'login'} = $urec->data('login');
						$done = 1;
					}
					else
					{
						$content->{'error'} = xml(
							'strong', [{}, 0, 'Error: '],
							0, 'Passwords do not match.',
						);
					}
				}
				else
				{
					$content->{'error'} = xml(
						'strong', [{}, 0, 'Error: '],
						0, 'Password must be at least 4 characters long.',
					);
				}
			}
			unless ($done)
			{
				$content->{'code'} = $form->{'code'};
				$content->{'update_pass'} = 1;
			}
		}
	}
	return $obj->SUPER::load($param);
}

sub reset
{
	my ($obj, $data, $args) = @_;
	my $content = $obj->content();
	my $em = $data->{'email'};
	$em =~ s/^\s+//;
	$em =~ s/\s+$//;
	if (length($em) && (length($em) <= 255))
	{
		my $urc = new Note::Row(
			'ring_user' => {'login' => $em},
		);
		if ($urc->id())
		{
			# send reset link
			my $user = new Ring::User('id' => $urc->id());
			$user->reset_email_send(
				'email' => $em,
			);
			$content->{'message'} = xml(
				'strong', [{}, 0, 'Reset Link Sent: '],
				0, 'A reset password link has been sent to your email address.',
			);
		}
		else
		{
			$content->{'error'} = xml(
				'strong', [{}, 0, 'Error: '],
				0, 'Email address not found.',
			);
		}
	}
}

1;

