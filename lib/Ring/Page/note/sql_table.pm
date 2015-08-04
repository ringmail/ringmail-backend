package Page::note::sql_table;
use strict;
use warnings;

use vars qw(@TYPES);

use Moose;
use JSON::XS;
use Data::Dumper;

use Note::XML 'xml';
use Note::Param;
use Note::File::JSON;

extends 'Note::Page';

no warnings 'uninitialized';

our @TYPES = (
	'Record', # bigint (unsigned)
	'Text', # char, varchar, text or longtext
	'Boolean', # int
	'Integer', # int
	'Currency', # decimal(24,4)
	'Decimal', # decimal
	'Float', # real, float, double
	'Binary', # binary, varbinary, blob or longblog
	'Date', # date
	'Datetime', # datetime, timestamp
);

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	$content->{'scripts'} = xml(
		'script', [{'src' => '/js/note/sql_table.js'}, 0, ''],
	);
	my @origin = map {(
		'tr', [{'id' => 't_'. $_},
			'td', [{},
				'i', [{'class' => 'icon-th'}, 0, ''],
				0, ' ',
				0, $_,
			],
		],
	)} (@TYPES);
	$content->{'origin_list'} = xml(@origin);
	my $fp = '/tmp/table.njs';
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
		::_log('List', $list);
		my @listxml = ();
		foreach my $i (0..$#{$list})
		{
			push @listxml, (
				'tr', [{'id' => 'i'. $i},
					$obj->html_row($list, $i),
				],
			);
		}
		unless (scalar @listxml)
		{
			push @listxml, (
				'tr', [{'id' => 'ph', 'class' => 'ph'},
					'td', [{'colspan' => '6', 'style' => 'text-align: center;'}, 0, '[ - Empty - ]'],
				],
			);
		}
		$content->{'list'} = xml(@listxml);
	}
	return $obj->SUPER::load($param);
}

sub html_row
{
	my ($obj, $list, $i) = @_;
	return (
		'td', [{},
			'i', [{'class' => 'icon-th'}, 0, ''],
		],
		'td', [{},
			0, $i + 1,
		],
		'td', [{},
			0, $list->[$i]->{'name'},
		],
		'td', [{},
			0, $list->[$i]->{'type'},
		],
		'td', [{},
			0, 'size',
		],
		'td', [{},
			0, 'sql type',
		],
	);
}

sub ajax_request
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	#::_log($form);
	my $file = $param->{'file'};
	my $inplist = $file->data()->{'list'};
	$obj->response()->content_type('application/json');
	my $res = 'OK';
	my $data = {};
	foreach my $k (keys %$form)
	{
		next if ($k eq 'cmd');
		eval {
			my $rc = decode_json($form->{$k});
			$data->{$k} = $rc;
		};
	}
	if ($form->{'cmd'} eq 'update_list')
	{
		my $list = $data->{'list'};
		if (ref($list) && $list =~ /ARRAY/)
		{
			@$list = grep {!/^ph$/} @$list; # remove placeholder
			my $nextid = scalar(@$list);
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
				elsif (ref($v))
				{
					if ($v->[0] =~ s/^t\_//)
					{
						my $nextname = 'field_'. $nextid;
						push @newlist, {
							'type' => $v->[0],
							'name' => $nextname,
						};
						$res = xml($obj->html_row(\@newlist, $#newlist));
					}
				}
			}
			shift @newlist if (scalar(@newlist) > 1 && ! defined $newlist[0]);
			$file->data()->{'list'} = \@newlist;
			::_log('List', $file->data()->{'list'});
			$file->write_file();
		}
		#$res = encode_json();
	}
	elsif ($form->{'cmd'} eq 'field_info')
	{
		my $fld = $data->{'info'}->{'field'};
		if ($fld =~ /^i(\d+)$/)
		{
			$fld = $1;
			if (exists $inplist->[$fld])
			{
				return xml(
					'form', [{'id' => 'field_form'},
						'label', [{}, 0, 'Field Name:'],
						0, $obj->field(
							'type' => 'text',
							'name' => 'field_name',
							'value' => $inplist->[$fld]->{'name'},
							'opts' => {
								'id' => 'field_name',
								'style' => 'width: 160px;',
							},
						),
						'br', [{}],
						'label', [{}, 0, 'Data Type:'],
						0, $obj->field(
							'type' => 'select',
							'name' => 'field_type',
							'opts' => {
								'id' => 'field_type',
								'style' => 'width: 174px;',
							},
							'select' => [
								map {[$_, $_]} @TYPES,
							],
							'selected' => $inplist->[$fld]->{'type'},
						),
					],
				);
			}
		}
		$obj->response()->status(500);
		return '';
	}
	#::_log("Res: $res");
	return $res;
}

1;

