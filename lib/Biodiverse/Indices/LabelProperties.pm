package Biodiverse::Indices::LabelProperties;
use strict;
use warnings;

use Carp;

our $VERSION = '0.16';

use Biodiverse::Statistics;
my $stats_class = 'Biodiverse::Statistics';

use Data::Dumper;

sub get_metadata_get_lbp_stats_objects {
    my $self = shift;

    my $desc = 'Get the stats object for the property values '
             . " across both neighbour sets\n";
    my %arguments = (
        description     => $desc,
        name            => 'Label property stats objects',
        type            => 'Element Properties',
        pre_calc        => ['calc_abc'],
        uses_nbr_lists  => 1,  #  how many sets of lists it must have
        indices => {
            LBPROP_STATS_OBJECTS => {
                description => 'hash of stats objects for the property values',
            },
        },
    );

    return wantarray ? %arguments : \%arguments;
}

sub get_lbp_stats_objects {
    my $self = shift;
    my %args = @_;

    my $label_hash_all = $args{label_hash_all};

    my $bd = $self->get_basedata_ref;
    my $lb = $bd->get_labels_ref;

    my %stats_objects;
    my %data;
    #  process the properties and generate the stats objects
    foreach my $prop ($lb->get_element_property_keys) {
        my $key = $self->_get_lbprop_stats_hash_key(property => $prop);
        $stats_objects{$key} = $stats_class->new();
        $data{$prop} = [];
    }

    #  loop over the labels and collect arrays of their elements.
    #  These are then added to the stats objects to save it
    #  recalculating all its stats each time.
    LABEL:
    while (my ($label, $count) = each %$label_hash_all) {
        my $properties = $lb->get_element_properties (element => $label);

        next LABEL if ! defined $properties;

        PROPERTY:
        while (my ($prop, $value) = each %$properties) {
            next PROPERTY if ! defined $value;

            my $data_ref = $data{$prop};
            push @$data_ref, ($value) x $count;  #  allow for possible calc_abc3 dependency
        }
    }
    
    ADD_DATA_TO_STATS_OBJECTS:
    foreach my $prop (keys %data) {
        my $stats_key = $self->_get_lbprop_stats_hash_key(property => $prop);
        my $stats = $stats_objects{$stats_key};
        my $data_ref = $data{$prop};
        $stats->add_data($data_ref);
    }

    my %results = (
        LBPROP_STATS_OBJECTS => \%stats_objects,
    );

    return wantarray ? %results : \%results;
}

sub _get_lbprop_stats_hash_key {
    my $self = shift;
    my %args = @_;
    my $prop = $args{property};
    return 'LBPROP_STATS_' . $prop . '_DATA';
}

sub _get_lbprop_stats_hash_keynames {
    my $self = shift;

    my $bd = $self->get_basedata_ref;
    my $lb = $bd->get_labels_ref;

    my %keys;
    #  what stats object names will we have?
    foreach my $prop ($lb->get_element_property_keys) {
        my $key = $self->_get_lbprop_stats_hash_key(property => $prop);
        $keys{$prop} = $key;
    }

    return wantarray ? %keys : \%keys;
}


sub get_metadata_calc_lbprop_data {
    my $self = shift;

    my $desc = 'Lists of the labels and their property values '
             . 'used in the label properties calculations';

    my %indices;
    my %prop_hash_names = $self->_get_lbprop_stats_hash_keynames;
    while (my ($prop, $list_name) = each %prop_hash_names) {
        $indices{$list_name} = {
            $list_name => 'List of data for property ' . $prop,
            type       => 'list',
        };
    }

    my %arguments = (
        description     => $desc,
        name            => 'Label property data',
        type            => 'Element Properties',
        pre_calc        => ['get_lbp_stats_objects'],
        uses_nbr_lists  => 1,
        indices         => \%indices,
    );

    return wantarray ? %arguments : \%arguments;
}

sub calc_lbprop_data {
    my $self = shift;
    my %args = @_;

    #  just grab the hash from the precalc results
    my %objects = %{$args{LBPROP_STATS_OBJECTS}};
    my %results;

    while (my ($prop, $stats_object) = each %objects) {
        $results{$prop} = [ $stats_object->get_data() ];
    }

    return wantarray ? %results : \%results;
}


sub get_metadata_calc_lbprop_hashes {
    my $self = shift;

    my $desc = 'Hashes of the labels and their property values '
             . 'used in the label properties calculations. '
             . 'Hash keys are the property values, '
             . 'hash values are the property value frequencies.';

    my %indices;
    my %prop_hash_names = $self->_get_lbprop_stats_hash_keynames;
    while (my ($prop, $list_name) = each %prop_hash_names) {
        $list_name =~ s/DATA$/HASH/;
        $indices{$list_name} = {
            $list_name => 'Hash of values for property ' . $prop,
            type       => 'list',
        };
    }

    my %arguments = (
        description     => $desc,
        name            => 'Label property hashes',
        type            => 'Element Properties',
        pre_calc        => ['get_lbp_stats_objects'],
        uses_nbr_lists  => 1,
        indices         => \%indices,
    );
    
    #print Data::Dumper::Dump \%arguments;

    return wantarray ? %arguments : \%arguments;
}


#  data in hash form
sub calc_lbprop_hashes {
    my $self = shift;
    my %args = @_;

    #  just grab the hash from the precalc results
    my %objects = %{$args{LBPROP_STATS_OBJECTS}};
    my %results;

    while (my ($prop, $stats_object) = each %objects) {
        my @data = $stats_object->get_data();
        my $key = $prop;
        $key =~ s/DATA$/HASH/;
        foreach my $value (@data) {
            $results{$key}{$value} ++;
        }
    }

    return wantarray ? %results : \%results;
}


my @stats     = qw /count mean min max median sum skewness kurtosis standard_deviation iqr/;
my %stat_name_short = (
    standard_deviation => 'SD',
);
my @quantiles = qw /05 10 20 30 40 50 60 70 80 90 95/;

sub get_metadata_calc_lbprop_stats {
    my $self = shift;

    my $desc = 'Summary statistics for each label property across both neighbour sets';

    my %arguments = (
        description     => $desc,
        name            => 'Label property summary stats',
        type            => 'Element Properties',
        pre_calc        => ['get_lbp_stats_objects'],
        uses_nbr_lists  => 1,
        indices         => {
            LBPROP_STATS => {
                description => 'Summary statistics for the label properties',
                type        => 'list',
            }
        },
    );

    return wantarray ? %arguments : \%arguments;
}

sub calc_lbprop_stats {
    my $self = shift;
    my %args = @_;

    #  just grab the hash from the precalc results
    my %objects = %{$args{LBPROP_STATS_OBJECTS}};
    my %res;

    while (my ($prop, $stats_object) = each %objects) {
        my $pfx = $prop;
        $pfx =~ s/DATA$//;
        $pfx =~ s/^LBPROP_STATS_//;
        foreach my $stat (@stats) {
            my $stat_name = exists $stat_name_short{$stat}
                        ? $stat_name_short{$stat}
                        : $stat;

            $res{$pfx . uc $stat_name} = eval {$stats_object->$stat};
        }
    }

    my %results = (LBPROP_STATS => \%res);

    return wantarray ? %results : \%results;
}


sub get_metadata_calc_lbprop_quantiles {
    my $self = shift;

    my $desc = 'Quantiles for each label property across both neighbour sets';

    my %arguments = (
        description     => $desc,
        name            => 'Label property quantiles',
        type            => 'Element Properties',
        pre_calc        => ['get_lbp_stats_objects'],
        uses_nbr_lists  => 1,
        indices         => {
            LBPROP_QUANTILES => {
                description => 'Quantiles for the label properties',
                type        => 'list',
            }
        },
    );

    return wantarray ? %arguments : \%arguments;
}

sub calc_lbprop_quantiles {
    my $self = shift;
    my %args = @_;

    #  just grab the hash from the precalc results
    my %objects = %{$args{LBPROP_STATS_OBJECTS}};
    my %res;

    while (my ($prop, $stats_object) = each %objects) {
        my $pfx = $prop;
        $pfx =~ s/DATA$/Q/;
        $pfx =~ s/^LBPROP_STATS_//;
        foreach my $stat (@quantiles) {
            $res{$pfx . $stat} = eval {$stats_object->percentile($stat)};
        }
    }

    my %results = (LBPROP_QUANTILES => \%res);

    return wantarray ? %results : \%results;
}


1;


__END__

=head1 NAME

Biodiverse::Indices::LabelProperties

=head1 SYNOPSIS

  use Biodiverse::Indices;

=head1 DESCRIPTION

Label property indices for the Biodiverse system.
It is inherited by Biodiverse::Indices and not to be used on it own.

See L<http://code.google.com/p/biodiverse/wiki/Indices> for more details.

=head1 METHODS

=over

=item INSERT METHODS

=back

=head1 REPORTING ERRORS

Use the issue tracker at http://www.purl.org/biodiverse

=head1 COPYRIGHT

Copyright (c) 2010 Shawn Laffan. All rights reserved.  

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

For a full copy of the license see <http://www.gnu.org/licenses/>.

=cut
