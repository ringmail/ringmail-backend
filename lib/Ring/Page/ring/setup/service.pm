package Page::ring::setup::service;
use strict;
use warnings;

use vars qw(%payment_check);

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;
use Note::Account 'has_account', 'create_account';
use Note::Payment;
use Note::Check;
use Note::Locale;

use Ring::User;

extends 'Page::ring::user';

no warnings 'uninitialized';

our %payment_check = (
	'first_name' => new Note::Check(
		'type' => 'regex',
		'chars' => 'A-Za-z0-9.- ',
	),
	'last_name' => new Note::Check(
		'type' => 'regex',
		'chars' => 'A-Za-z0-9.- ',
	),
	'address' => new Note::Check(
		'type' => 'regex',
		'chars' => 'A-Za-z0-9.- #/',
	),
	'address2' => new Note::Check(
		'type' => 'regex',
		'chars_empty' => 1,
		'chars' => 'A-Za-z0-9.- #/',
	),
	'city' => new Note::Check(
		'type' => 'regex',
		'chars' => 'A-Za-z.- ',
	),
	'zip' => new Note::Check(
		'type' => 'regex',
		'regex' => qr/^\d{5}$/,
	),
	'state' => new Note::Check(
		'type' => 'valid',
		'valid' => sub {
			my ($sp, $data) = @_;
			unless (exists $Note::Locale::states{$$data})
			{
				Note::Check::fail('Invalid state');
			}
		},
	), 
	'phone' => new Note::Check(
		'type' => 'valid',
		'valid' => sub {
			my ($sp, $data) = @_;
			my $ph = $$data;
			$ph =~ s/\D//g;
			unless (length($ph) == 10)
			{
				Note::Check::fail('Invalid phone number');
			}
			return 1;
		},
	),
);

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::_log($form);
	my $content = $obj->content();
	my $user = $obj->user();
	$content->{'payment'} = $obj->show_payment_form();
	return $obj->SUPER::load($param);
}

sub cmd_fund
{
	my ($obj, $data, $args) = @_;
	::_log("Fund:", $data);
	my $rec = {};
	my @err = ();
	foreach my $k (qw/first_name last_name address address2 city email/)
	{
		if (defined $data->{$k})
		{
			$data->{$k} =~ s/^\s+//g;
			$data->{$k} =~ s/\s+$//g;
		}
	}
	my %label = (
		'first_name' => 'First Name',
		'last_name' => 'Last Name',
		'phone' => 'Phone',
		'address' => 'Address',
		'address2' => 'Address (2)',
		'city' => 'City',
		'state' => 'State',
		'zip' => 'Zip',
	);
	foreach my $k (sort keys %payment_check)
	{
		my $data = $data->{$k};
		my $cr = $payment_check{$k};
		if ($cr->valid(\$data))
		{
			$rec->{$k} = $data;
		}
		else
		{
			my $tm = $label{$k};
			if (length($data))
			{
				push @err, $tm. ': '. $cr->error();
			}
			elsif ($k ne 'address2')
			{
				push @err, $tm. ': Required';
			}
		}
	}
	if (exists $rec->{'phone'})
	{
		$rec->{'phone'} =~ s/\D//g;
	}
	my $uid = $obj->user()->id();
	my $pmt = new Note::Payment($uid);
	my $carderr = '';
	unless ($data->{'cc_cvv2'} =~ /^\d{3,4}$/)
	{
		push @err, 'Security Code: Required';
	}
	my $num = $data->{'cc_num'};
	$num =~ s/\D//g;
	my $cardok = $pmt->card_check(
		'num' => $num,
		'expy' => $data->{'cc_expy'},
		'expm' => $data->{'cc_expm'},
		'type' => $data->{'cc_type'},
		'error' => \$carderr,
	);
	if ($carderr)
	{
		push @err, 'Credit Card: '. $carderr;
	}
	if (scalar @err)
	{
		$obj->value()->{'data'} = $rec;
		$obj->value()->{'error'} = join('</br>', @err);
		return;
	}
	if ($cardok)
	{
		my $cid = $pmt->card_add(
			'num' => $num,
			'expy' => $data->{'cc_expy'},
			'expm' => $data->{'cc_expm'},
			'type' => $data->{'cc_type'},
			'cvv2' => $data->{'cc_cvv2'},
			'first_name' => $rec->{'first_name'},
			'last_name' => $rec->{'last_name'},
			'address' => $rec->{'address'},
			'address2' => $rec->{'address2'},
			'city' => $rec->{'city'},
			'state' => $rec->{'state'},
			'zip' => $rec->{'zip'},
		);
		my $act = (has_account($uid)) ? new Note::Account($uid) : create_account($uid);
		my $attempt = $pmt->card_payment(
			'processor' => 'paypal',
			'card_id' => $cid,
			'nofork' => 0,
			'amount' => '9.98',
			'ip' => $obj->env()->{'REMOTE_ADDR'},
			'callback' => sub {
				::_log("New Balance: ". $act->balance());
			},
		);
		my $sd = $obj->session();
		$sd->{'payment_attempt'} = $attempt;
		$obj->session_write();
		::_log("Attempt: ". $attempt);
		return $obj->redirect('/u/settings/processing');
	}
}

1;

