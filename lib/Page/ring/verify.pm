package Page::ring::verify;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';
use Scalar::Util 'blessed';
use Try::Tiny;

use Note::XML 'xml';
use Note::Param;

use Ring::User;
use Ring::Exception;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	if (exists $form->{'code'})
	{
		try {
			my $rc = new Note::Row(
				'ring_verify_email' => {
					'verify_code' => $form->{'code'},
				},
				{
					'select' => [qw/verified user_id email_id/],
				},
			);
			if ($rc->id())
			{
				my $user = new Ring::User($rc->data('user_id'));
				if ($user->verify_email(
					'record' => $rc,
				)) {
					$content->{'message'} = xml(
						'strong', [{}, 0, 'Success: '],
						0, 'Email verified, you can now login.',
					);
					$content->{'email'} = $rc->row('email_id', 'ring_email')->data('email');
				}
				else
				{
					$content->{'error'} = xml(
						'strong', [{}, 0, 'Error: '],
						0, 'Email address already verified.',
					);
				}
			}
			else
			{
				$content->{'error'} = xml(
					'strong', [{}, 0, 'Error: '],
					0, 'Invalid verification code.',
				);
			}
		} catch {
			if (blessed($_))
			{
				::errorlog('Internal Error: '. $_->message());
			}
			else
			{
				::errorlog('Internal Error: '. $_);
			}
			$content->{'error'} = xml(
				'strong', [{}, 0, 'Error: '],
				0, 'Internal error.',
			);
		};
	}
	return $obj->SUPER::load($param);
}

1;

