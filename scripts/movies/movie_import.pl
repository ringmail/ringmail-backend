#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Data::Dumper;
use Note::Base;
use JSON::XS;

my $itr = new Note::Iterator(
    'file' => 'movies_2017_filtered.csv',
    'type' => 'csv',
    'csv_fields' => 1,
);

sub make_genre
{
	my $genre = shift;
	my $tmdb = shift;
	my $found = new Note::Row(
		'movie_genre' => {
			'name' => $genre,
		},
	);
	if ($found->{'id'})
	{
		return $found;
	}
	else
	{
		return Note::Row::insert('movie_genre', {
			'name' => $genre,
			'tmdb_genre_id' => $tmdb,
		});
	}
}

sub make_movie
{
	my $data = shift;
	my $primary_genre = shift;
	my $found = new Note::Row(
		'movie' => {
			'tmdb_id' => $data->{'ID'},
		},
	);
	if ($found->{'id'})
	{
		return $found;
	}
	else
	{
		my $yt = '';
		if ($data->{'Video'} =~ /^youtube\s+(.*)$/i)
		{
			$yt = $1;
		}
		my $rec = {
			'adult' => (lc($data->{'Adult'}) ne 'false') ? 1 : 0,
			'backdrop_url' => $data->{'Backdrop'},
			'genre_json' => $data->{'Genres'},
			'hashtag' => $data->{'Hashtag'},
			'homepage' => $data->{'Homepage'},
			'original_language' => $data->{'Original Language'},
			'overview' => $data->{'Overview'},
			'popularity' => $data->{'Popularity'},
			'poster_url' => $data->{'Poster'},
			'primary_genre' => $primary_genre,
			'release_date' => $data->{'Release Date'},
			'release_status' => $data->{'Status'},
			'title' => $data->{'Movie Title'},
			'tmdb_id' => $data->{'ID'},
			'youtube_id' => $yt,
		};
		return Note::Row::insert('movie', $rec);
	}
}

sub make_lookup
{
	my $mov = shift;
	my $gen = shift;
	return if (sqltable('movie_genre_lookup')->count(
		'movie_id' => $mov->id(),
		'genre_id' => $gen->id(),
	));
	Note::Row::insert('movie_genre_lookup', {
		'movie_id' => $mov->id(),
		'genre_id' => $gen->id(),
	});
}

while ($itr->has_next())
{
    my $val = $itr->value();
	my $genres = decode_json($val->{'Genres'});
	my @grec = ();
	foreach my $g (@$genres)
	{
		push @grec, make_genre($g->{'name'}, $g->{'id'});
	}
	my $topgenre = (sort {
		$b->{'id'} <=> $a->{'id'}
	} @$genres)[0];
	my $toprec = make_genre($topgenre->{'name'}, $topgenre->{'id'});
	my $mov = make_movie($val, $toprec->id());
	#::log($val, $mov);
	foreach my $gr (@grec)
	{
		make_lookup($mov, $gr);
	}
}

