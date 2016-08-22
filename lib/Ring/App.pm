package Ring::App;
use strict;
use warnings;

use vars qw();

use Moose;
use Data::Dumper;

use Note::Param;
use Note::App;
use base qw(Note::App);

no warnings qw(uninitialized);

# default, directory lookup dispatcher
sub dispatch
{
	my ($obj, $param) = get_param(@_);
	#::log("Dispatch: ". join('/', @{$param->{'path'}}));
	my $path = $param->{'path'};
	if (scalar(@$path))
	{
		if ($path->[0] =~ /^hashtag$/i)
		{
			my $ht = lc($path->[1]);
			if ($ht =~ /^[\w\d\_]+$/)
			{
				#::log("Hashtag: $ht");
				$param->{'form'}->{'hashtag'} = $ht;
				$param->{'path'} = ['internal', 'page', 'hashtag'];
			}
		}
	}
	return $obj->SUPER::dispatch($param);
}

1;

