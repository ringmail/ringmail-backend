package Page::note::dnd;
use strict;
use warnings;

use Moose;
use JSON::XS;
use Note::XML 'xml';
use Note::Param;
use Note::File::JSON;

extends 'Note::Page';

no warnings 'uninitialized';

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	my $fp = '/tmp/test.njs';
	my $file = new Note::File::JSON(
		'file' => $fp,
	);
	if ($file->exists())
	{
		$file->read_file();
	}
	else
	{
		$file->data({
			'list' => [],
		});
		$file->write_file();
	}
	if ($form->{'ajax'} eq '1')
	{
		return $obj->ajax_request(
			'file' => $file,
		);
	}
	else
	{
		my $list = $file->data()->{'list'};
		my @listxml = ();
		foreach my $i (0..$#{$list})
		{
			push @listxml, (
				'li', [{'id' => 'i'. $i},
					'a', [{'href' => '#'}, 0, $list->[$i]->{'name'}],
				],
			);
		}
		unless (scalar @listxml)
		{
			push @listxml, (
				'li', [{'id' => 'ph', 'class' => 'ph'},
					'a', [{'href' => '#'}, 0, '[ - Empty - ]'],
				],
			);
		}
		$content->{'list'} = xml(@listxml);
	}
	return $obj->SUPER::load($param);
}

sub ajax_request
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $file = $param->{'file'};
	my $inplist = $file->data()->{'list'};
	$obj->response()->content_type('application/json');
	my $data = {};
	foreach my $k (keys %$form)
	{
		eval {
			my $rc = decode_json($form->{$k});
			$data->{$k} = $rc;
		};
	}
	my $list = $data->{'list'};
	my $res = 'OK';
	if (ref($list) && $list =~ /ARRAY/)
	{
		@$list = grep {!/^ph$/} @$list; # remove placeholder
		my @newlist = ();
		foreach my $i (0..$#{$list})
		{
			my $v = $list->[$i];
			if ($v =~ /^i(\d+)$/)
			{
				my $p = $1;
				#::_log("$p $inplist->[$p]");
				push @newlist, $inplist->[$p];
			}
			elsif ($v =~ /^\w$/)
			{
				push @newlist, {
					'name' => $v,
				};
			}
		}
		shift @newlist if (scalar(@newlist) > 1 && ! defined $newlist[0]);
		$file->data()->{'list'} = \@newlist;
		::_log($file->data());
		$file->write_file();
		#$res = encode_json();
	}
	return $res;
}

1;

