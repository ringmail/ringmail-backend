package Ring::Item;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';

use Note::Param;
use Note::Row;

no warnings qw(uninitialized);

# find or create method
# type: did
#  did, did_code
sub item
{
	my ($obj, $param) = get_param(@_);
	my $type = $param->{'type'};
	if ($type eq 'did')
	{
		my $did = $param->{'did_number'};
		$did =~ s/^\D//g;
		my $code = '';
		if (defined $param->{'did_code'})
		{
			$code = $param->{'did_code'};
		}
		else
		{
			if (length($did) == 10)
			{
				$code = 1;
			}
			elsif ((length($did) == 11) && ($did =~ /^1/))
			{
				$code = 1;
				$did =~ s/^1//;
			}
			else
			{
				die('Invalid did number'); # non US/Canada number not supported yet
			}
		}
		return Note::Row::find_create(
			'ring_did' => {
				'did_code' => $code,
				'did_number' => $did,
			},
		);
	}
	elsif ($type eq 'sip')
	{
		return Note::Row::find_create(
			'ring_sip' => {
				'sip_url' => $param->{'sip_url'},
			},
		);
	}
	elsif ($type eq 'domain')
	{
		my $dom = lc($param->{'domain'});
		return Note::Row::find_create(
			'ring_domain' => {
				'domain' => $dom,
			},
			{
				'domain_reverse' => scalar reverse($dom),
			}
		);
	}
	elsif ($type eq 'domain_user')
	{
		return Note::Row::find_create(
			'ring_domain_user' => {
				'domain_id' => $param->{'domain_id'},
				'username' => $param->{'username'},
			},
		);
	}
	elsif ($type eq 'email')
	{
		my $em = lc($param->{'email'});
		my $created = 0;
		my $erec = Note::Row::find_create(
			'ring_email',
			{
				'email' => $em,
			},
			{
				'domain_id' => 0,
				'domain_user_id' => 0,
			},
			\$created,
		);
		if ($created)
		{
			my ($username, $domain) = split /\@/, $em, 2;
			my $drec = $obj->item(
				'type' => 'domain',
				'domain' => $domain,
			);
			my $urec = $obj->item(
				'type' => 'domain_user',
				'domain_id' => $drec->id(),
				'username' => $username,
			);
			$erec->update({
				'domain_id' => $drec->id(),
				'domain_user_id' => $urec->id(),
			});
		}
		return $erec;
	}
	elsif ($type eq 'product')
	{
		return Note::Row::find_create(
			'ring_product' => {
				'name' => $param->{'name'},
			},
		);
	}
	elsif ($type eq 'device')
	{
		return Note::Row::find_create(
			'ring_device' => {
				'user_id' => $param->{'user_id'},
				'device_uuid' => $param->{'device_uuid'},
			},
		);
	}
}

1;

