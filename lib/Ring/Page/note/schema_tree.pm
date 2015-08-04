package Page::note::schema_tree;
use strict;
use warnings;

use vars qw();

use Moose;
use JSON::XS 'encode_json';
use Data::Dumper;
use RDF::Trine ('iri', 'statement', 'literal', 'blank');
use RDF::Trine::Model;
use RDF::Trine::Node;
use HTML::Entities 'encode_entities';
use POSIX 'strftime';

use Note::XML 'xml';
use Note::Param;
use Note::File::JSON;
use Note::RDF::Class;
use Note::RDF::NS 'ns_iri', 'ns_match';

extends 'Note::Page';

no warnings 'uninitialized';

has 'subject' => (
	'is' => 'rw',
	'isa' => 'RDF::Trine::Node',
);

has 'model' => (
	'is' => 'rw',
	'isa' => 'RDF::Trine::Model',
);

sub load
{
	my ($obj, $param) = get_param(@_);
	my $form = $obj->form();
	my $content = $obj->content();
	#$content->{'scripts'} = xml();
	#$content->{'origin_list'} = xml(@origin);
	my $fp = '/home/note/run/perl/schema/schema_org.njs';
	my $file = new Note::File::JSON(
		'file' => $fp,
	);
	$file->read_file();
	if ($form->{'ajax'} eq '1')
	{
		return $obj->ajax_request(
			'file' => $file,
		);
	}
	else
	{
		my $list = $file->data()->{'data'};
		my $listiter;
		$listiter = sub {
			my ($items) = @_;
			my @res = ();
			foreach my $i (@$items)
			{
				my $more = '';
				if (exists $i->{'subclass'})
				{
					$more = $listiter->($i->{'subclass'});
				}
				push @res, (
					'li', [{
						'data' => "class: '$i->{'class'}'",
					},
						0, $i->{'class'},
						0, $more,
					],
				);
			}
			if (scalar @res)
			{
				return xml(
					'ul', [{},
						@res
					],
				);
			}
			return '';
		};
		$content->{'tree'} = $listiter->($list);
	}
	return $obj->SUPER::load($param);
}

sub ajax_request
{
	my ($obj, $param) = get_param(@_);
	my $db = $obj->storage()->{'atx_virtuoso_1'};
	$db->context(iri('http://schema.rdfs.org/all'));
	my $sess = $obj->session();
	my $model = $sess->get('model');
	$model ||= new RDF::Trine::Model();
	$obj->model($model);
	my $form = $obj->form();
	::_log($form);
	$obj->response()->content_type('text/html');
	my $res = '';
	if ($form->{'cmd'} eq 'get_class')
	{
		my $class = new Note::RDF::Class(
			'sparql' => $db,
			'class' => iri($form->{'class'}),
		);
		my $inst = $form->{'instance'};
		my $sbj = undef;
		if ($inst =~ s/^blank:\/\///) # blank node
		{
			$sbj = blank($inst);
			$obj->subject($sbj);
		}
		else
		{
			$sbj = iri($inst);
			$obj->subject($sbj);
		}
		#my $attrs = $class->get_super_all();
		my $attrs = $class->get_properties_all(
			'show_class' => 1,
		);
		my %cls = ();
		my %pdata = ();
		my $attrtxt = '';
		foreach my $prop (@$attrs)
		{
			my $cl = $prop->[0]->uri_value();
			my $puri = $prop->[1]->uri_value();
			my $rdata = $db->get_resource($prop->[1]);
			$pdata{$puri} = $db->get_resource($prop->[1]);
			my $info = {
				'class' => $cl,
				'property' => $puri,
				'label' => $rdata->get_statements($prop->[1], ns_iri('rdfs', 'label'), undef)->next()->object()->literal_value(),
				'comment' => $rdata->get_statements($prop->[1], ns_iri('rdfs', 'comment'), undef)->next()->object()->literal_value(),
				'range' => $rdata->get_statements($prop->[1], ns_iri('rdfs', 'range'), undef)->next()->object(),
			};
			$cls{$cl}->{$puri} = $info;
		}
		my %seencl = ();
		foreach my $i ($form->{'class'}, sort keys %cls)
		{
			next if ($seencl{$i}++);
			my $clp = $cls{$i};
			unless ($i eq $form->{'class'})
			{
				my $label = $obj->get_label('item' => iri($i));
				$attrtxt .= xml('h4', [{}, 0, $label. ':']);
			}
			foreach my $ak (sort keys %$clp)
			{
				my $atdata = $clp->{$ak};
				$attrtxt .= $obj->build_attr($atdata);
			}
		}
		my $label = $obj->get_label('item' => iri($form->{'class'}));
		my $popovers = $obj->{'html_popover'};
		if (defined($popovers) && scalar @$popovers)
		{
			$popovers = xml('script', [{}, (map {(0, $_)} @$popovers)]);
		}
		else
		{
			$popovers = '';
		}
		my $heading = '';
		my $instlbl = '';
		if (defined($sbj))
		{
			$heading = $obj->get_name('item' => $sbj);
			$instlbl = $heading;
		}
		else
		{
			$heading = 'New '. $label. ':';
			$instlbl = xml('em', [{}, 0, $heading]);
		}
		$res = xml(
			'h3', [{'style' => 'margin-top: 0px;'},
				0, $heading,
			],
			'form', [{
				'method' => 'post',
				'action' => $obj->url(),
				'style' => 'margin: 0px; padding: 0px;',
				'class' => 'form-horizontal',
				'id' => 'create-form',
			},
				'fieldset', [{},
					0, $attrtxt,
					'div', [{'class' => 'control-group'},
						'div', [{'class' => 'controls'},
							0, $obj->hidden({'class' => $form->{'class'}}),
							'button', [{
								'class' => 'btn',
								'onclick' => q|return update_form('create-form');|,
							},
								0, 'Create',
							],
						],
					],
				],
			],
			0, $popovers,
		);
		$obj->response()->content_type('application/json');
		$res = encode_json({
			'instance_form' => $res,
			'instance_label' => $instlbl,
			'class_label' => $label,
		});
	}
	elsif ($form->{'cmd'} eq 'get_instance_list')
	{
		#::_log("Get Instances", $form);
		my $curl = $form->{'class'};
		my $class = iri($curl);
		#print $model->as_string();
		my $stmts = $model->get_statements(undef, ns_iri('rdf', 'type'), $class);
		my @res = ();
		my $popid = $form->{'popid'};
		while (my $r = $stmts->next())
		{
			my $sbj = $r->subject();
			if ($sbj->is_blank())
			{
				my $blid = $sbj->blank_identifier();
				my @name = ();
				my $nq = $model->get_statements($sbj, iri('http://schema.org/'. 'name'), undef);
				my $n = undef;
				if ($n = $nq->next())
				{
					if ($n->object()->is_literal())
					{
						@name = (
							0, encode_entities($n->object()->literal_value()),
						);
					}
				}
				unless (scalar @name)
				{
					@name = (
						'em', [{},
							0, 'Item '. $blid,
						],
					);
				}
				my $inst = 'blank://0';
				if (defined($sbj))
				{
					if ($sbj->is_blank())
					{
						$inst = 'blank://'. $sbj->blank_identifier();
					}
					elsif ($sbj->is_resource())
					{
						$inst = $sbj->uri_value();
					}
				}
				push @res, (
					'div', [{},
						'a', [{'href' => '#', 'onclick' => "return edit_instance('$curl', '$inst');"},
							@name,
						],
					],
				);
			}
		}
		if (scalar @res)
		{
			@res = (
				'form', [{
					'method' => 'post',
					'action' => $obj->url(),
					'style' => 'margin: 0px; padding: 0px;',
					'id' => 'instance-list-form',
				},
					'input', [{
						'type' => 'hidden',
						'name' => 'class',
						'value' => $curl,
					}, 0, ''],
					@res,
				],
			);
		}
		else
		{
			@res = (
				'div', [{},
					'em', [{},
						0, 'No Items',
					],
				],
			);
		}
		my $cls = $form->{'class'};
		my $label = $obj->get_label('item' => iri($cls));
		my $inst = 'blank://0';
		my $html = xml(
			'h3', [{},
				0, $label. ' List:',
			],
			'div', [{},
				'a', [{'href' => '#', 'onclick' => qq|return edit_instance('$cls', '$inst')|},
					0, 'Create '. $label,
				],
			],
			'hr', [{}],
			@res,
		);
		$obj->response()->content_type('application/json');
		my $json = encode_json({
			'instance_list' => $html,
			'class_label' => $label,
		});
		return $json;
	}
	elsif ($form->{'cmd'} eq 'select_instance_list')
	{
		#::_log("Get Instances", $form);
		my $curl = $form->{'class'};
		my $class = iri($curl);
		#print $model->as_string();
		my $stmts = $model->get_statements(undef, ns_iri('rdf', 'type'), $class);
		my @res = ();
		my $popid = $form->{'popid'};
		while (my $r = $stmts->next())
		{
			my $sbj = $r->subject();
			if ($sbj->is_blank())
			{
				my $blid = $sbj->blank_identifier();
				my @name = ();
				my $nq = $model->get_statements($sbj, iri('http://schema.org/'. 'name'), undef);
				my $n = undef;
				if ($n = $nq->next())
				{
					if ($n->object()->is_literal())
					{
						@name = (
							0, encode_entities($n->object()->literal_value()),
						);
					}
				}
				unless (scalar @name)
				{
					@name = (
						'em', [{},
							0, 'Item '. $blid,
						],
					);
				}
				push @res, (
					'div', [{},
						'a', [{'href' => '#', 'onclick' => "return add_instance('$popid', 1, '$blid');"},
							@name,
						],
					],
				);
			}
		}
		if (scalar @res)
		{
			@res = (
				'form', [{
					'method' => 'post',
					'action' => $obj->url(),
					'style' => 'margin: 0px; padding: 0px;',
					'id' => 'select-form',
				},
					'input', [{
						'type' => 'hidden',
						'name' => 'class',
						'value' => $curl,
					}, 0, ''],
					@res,
				],
			);
		}
		else
		{
			@res = (
				'div', [{'style' => 'text-align: center;'},
					'em', [{},
						0, 'No Items',
					],
				],
			);
		}
		my $html = xml(@res);
		return $html;
	}
	elsif ($form->{'cmd'} eq 'add_instance')
	{
		::_log("Add Instances", $form);
		#my $curl = $form->{'class'};
		#my $class = iri($curl);
		return '';
	}
	elsif ($form->{'cmd'} eq 'create')
	{
		my $class = iri($form->{'class'});
		my $rdfmeta = $sess->get('model_meta');
		$rdfmeta ||= {};
		$rdfmeta->{'count'}++;
		my $instiri = blank($rdfmeta->{'count'});
		$model->add_statement(
			statement($instiri, ns_iri('rdf', 'type'), $class),
		);
		foreach my $k (sort keys %$form)
		{
			my $v = $form->{$k};
			if ($k =~ s{^data_}{})
			{
				my $prop = iri('http://schema.org/'. $k);
				my $rq = $db->get_statements($prop, ns_iri('rdfs', 'range'), undef);
				if (my $r = $rq->next())
				{
					my $range = $r->object()->uri_value();
					my $inst = '';
					my $fld = '';
					if ($range =~ m{^nodeID://})
					{
					}
					elsif (my $match = ns_match($range, \$inst))
					{
						if ($match eq 'xsd')
						{
							if ($inst eq 'string' || $inst eq 'decimal')
							{
								$model->add_statement(
									statement($instiri, $prop, literal($v, undef, iri($range))),
								);
							}
							elsif ($inst eq 'boolean')
							{
								$model->add_statement(
									statement($instiri, $prop, literal(($v eq 'on') ? 1 : 0, undef, iri($range))),
								);
							}
						}
						elsif ($match eq 'rdfs')
						{
							if ($inst eq 'Resource')
							{
								$model->add_statement(
									statement($instiri, $prop, iri($v)),
								);
							}
						}
					}
					elsif ($range =~ s{^http://schema.org/}{})
					{
					}
				}
			}
		}
		::_log($form);
		print $model->as_string();
		$sess->set('model_meta', $rdfmeta);
		$sess->set('model', $model);
	}
	#::_log("Res: $res");
	return $res;
}

sub build_attr
{
	my ($obj, $param) = get_param(@_);
	my $db = $obj->storage()->{'atx_virtuoso_1'};
	$db->context(iri('http://schema.rdfs.org/all'));
	my $range = $param->{'range'}->uri_value();
	my $inst = '';
	my $k = $param->{'property'};
	# read current resource
	my $values = '';
	my $sbj = $obj->subject();
	my $model = $obj->model();
	if (defined ($sbj))
	{
		if ($sbj->is_blank())
		{
			my $blid = $sbj->blank_identifier();
			unless ($blid eq '0')
			{
				my $pq = $model->get_statements($sbj, iri($k), undef);
				while (my $r = $pq->next())
				{
					my $v = $r->object();
					if ($v->is_literal())
					{
						$values .= xml(
							'p', [{'style' => 'margin-left: 24px; margin-bottom: 0px; margin-top: 6px; padding: 2px 4px 2px 4px; border: 1px #777777 solid; width: 207px;'}, 0, $v->literal_value()],
						);
					}
					elsif ($v->is_resource())
					{
						$values .= xml(
							'div', [{}, 0, $v->uri_value()],
						);
					}
				}
			}
		}
	}
	#
	$k =~ s{^http://schema.org/}{};
	my $fld = '';
	if ($range =~ m{^nodeID://})
	{
		my $ri = $param->{'range'};
		$range = '';
		my $rdata = $db->build_sparql(
			'select' => ['?list'],
			'where' => [
				[$ri, ns_iri('rdf', 'type'), ns_iri('owl', 'Class')],
				[$ri, ns_iri('owl', 'unionOf'), '?list'],
			],
		);
		if (my $i = $rdata->next())
		{
			my $list = $db->get_rdf_list(
				'list' => $i->{'list'},
			);
			my @types = map {$_->uri_value()} @$list;
			foreach my $i (0..$#types)
			{
				my $type = $types[$i];
				my $label;
				my $inst;
				if ($type =~ m{^http://schema.org/})
				{
					$label = $obj->get_label('item' => iri($types[$i]));
				}
				elsif (ns_match($type, \$inst) eq 'xsd')
				{
					$label = 'xsd:'. $inst;
				}
				my $classid = $obj->{'html_class'};
				my $orig = $types[$i];
				$classid->{$orig}++;
				my $id = $orig;
				$id =~ s{^http://schema.org/}{};
				$id = 'class_'. $id. '_'. $classid->{$orig};
				$obj->{'html_popover'} ||= [];
				push @{$obj->{'html_popover'}}, qq|setup_popover('$id', '$orig');\n|;
				$types[$i] = xml(
					'a', [{'href' => '#', 'id' => $id, 'onclick' => qq|return hit_popover('$id');|},
						0, $label,
					],
				);
			}
			$range .= join(' | ', sort @types);
			$range = xml(
				'div', [{'style' => 'padding-top: 5px;'},
					'i', [{'class'=> 'icon-leaf', 'style' => 'margin: 4px;'}, 0, ''],
					'span', [{'class' => 'well', 'style' => 'padding: 4px; padding-left: 8px; padding-right: 8px; margin: 0px;'},
						0, $range,
					],
				],
			);
		}
	}
	elsif (my $match = ns_match($range, \$inst))
	{
		if ($match eq 'xsd')
		{
			#$range = 'XSD: '. $inst;
			if ($inst eq 'string')
			{
				$fld = xml(
					'i', [{'class'=> 'icon-font', 'style' => 'margin: 4px;'}, 0, ''],
					0,  $obj->field(
						'name' => 'data_'. $k,
						'type' => 'text',
						'opts' => {
							'id' => 'data_'. $k,
							'placeholder' => 'Text',
						},
					),
				);
			}
			elsif ($inst eq 'decimal')
			{
				$fld = xml(
					'i', [{'class'=> 'icon-asterisk', 'style' => 'margin: 4px;'}, 0, ''],
					0,  $obj->field(
						'name' => 'data_'. $k,
						'type' => 'text',
						'opts' => {
							'id' => 'data_'. $k,
							'placeholder' => 'Decimal',
						},
					),
				);
			}
			elsif ($inst eq 'boolean')
			{
				$fld = xml(
					'i', [{'class'=> 'icon-ok', 'style' => 'margin: 4px;'}, 0, ''],
					0, $obj->field(
						'name' => 'data_'. $k,
						'type' => 'checkbox',
						'opts' => {
							'id' => 'data_'. $k,
						},
					),
				);
			}
			elsif ($inst eq 'date')
			{
				$fld = xml(
					'i', [{'class'=> 'icon-calendar', 'style' => 'margin: 4px;'}, 0, ''],
					0, $obj->field(
						'name' => 'data_'. $k,
						'type' => 'text',
						'opts' => {
							'id' => 'data_'. $k,
							'placeholder' => 'Date',
							'style' => 'width: 100px;',
							'data-date' => strftime("%F", localtime()),
							'data-date-format' => 'yyyy-mm-dd',
						},
					),
					'script', [{}, 0, qq|\$('#data_$k').datepicker();|],
				);
			}
		}
		elsif ($match eq 'rdfs')
		{
			#$range = 'RDFS: '. $inst;
			if ($inst eq 'Resource')
			{
				$fld = xml(
					'i', [{'class'=> 'icon-globe', 'style' => 'margin: 4px;'}, 0, ''],
					0, $obj->field(
						'name' => 'data_'. $k,
						'type' => 'text',
						'opts' => {
							'id' => 'data_'. $k,
							'placeholder' => 'URL',
						},
					),
				);
			}
		}
	}
	elsif ($range =~ m{^http://schema.org/})
	{
		my $label = $obj->get_label('item' => iri($range));
		$obj->{'html_class'} ||= {};
		my $classid = $obj->{'html_class'};
		$classid->{$range}++;
		my $id = $range;
		my $orig = $range;
		$id =~ s{^http://schema.org/}{};
		$id = 'class_'. $id. '_'. $classid->{$range};
		$obj->{'html_popover'} ||= [];
		push @{$obj->{'html_popover'}}, qq|setup_popover('$id', '$orig');\n|;
		$range = xml(
			'div', [{'style' => 'padding-top: 5px;'},
				'i', [{'class'=> 'icon-leaf', 'style' => 'margin: 4px;'}, 0, ''],
				'span', [{'class' => 'well', 'style' => 'padding: 4px; padding-left: 8px; padding-right: 8px; margin: 0px;'},
					'a', [{'href' => '#', 'id' => $id, 'onclick' => qq|return hit_popover('$id');|},
						0, $label,
					],
				],
			],
		);
	}
	$fld ||= $range;
	return xml(
		'div', [{'class' => 'control-group'},
			'label', [{'class' => 'control-label'}, 0, $param->{'label'}],
			'div', [{'class' => 'controls'},
				0, $fld,
				0, $values,
			],
		],
		#'span', [{'class' => 'help-block'},
			#0, $param->{'comment'},
		#],
	);
}

sub get_label
{
	my ($obj, $param) = get_param(@_);
	my $item = $param->{'item'};
	my $uri = $item->uri_value();
	return $obj->{'cache_label'}->{$uri} if (exists $obj->{'cache_label'}->{$uri});
	my $db = $obj->storage()->{'atx_virtuoso_1'};
	$db->context(iri('http://schema.rdfs.org/all'));
	my $rq = $db->get_statements($item, ns_iri('rdfs', 'label'), undef);
	if (my $r = $rq->next())
	{
		my $lbl = $r->object()->literal_value();
		$obj->{'cache_label'}->{$uri} = $lbl;
		return $lbl;
	}
	return undef;
}

sub get_name
{
	my ($obj, $param) = get_param(@_);
	my $item = $param->{'item'};
	my $uri = $item->uri_value();
	return encode_entities($obj->{'cache_name'}->{$uri}) if (exists $obj->{'cache_name'}->{$uri});
	my $model = $obj->model();
	my $rq = $model->get_statements($item, iri('http://schema.org/'. 'name'), undef);
	if (my $r = $rq->next())
	{
		my $lbl = $r->object()->literal_value();
		$obj->{'cache_name'}->{$uri} = $lbl;
		return encode_entities($lbl);
	}
	return undef;
}

1;

