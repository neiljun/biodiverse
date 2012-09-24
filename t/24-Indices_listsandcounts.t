#!/usr/bin/perl -w

use strict;
use warnings;

local $| = 1;

use rlib;
use Test::More;

use Biodiverse::TestHelpers qw{
    :runners
};

run_indices_test1 (
    calcs_to_test  => [qw/
        calc_elements_used
        calc_element_lists_used
        calc_abc_counts
        calc_d
        calc_local_range_lists
        calc_local_range_stats
        calc_redundancy
        calc_richness
        calc_local_sample_count_lists
        calc_local_sample_count_stats
    /],
    calc_topic_to_test => 'Lists and Counts',
);

done_testing;

1;

__DATA__

@@ RESULTS_2_NBR_LISTS
{
  'ABC2_LABELS_ALL' => {
                         'Genus:sp1'  => 2,
                         'Genus:sp10' => 1,
                         'Genus:sp11' => 2,
                         'Genus:sp12' => 2,
                         'Genus:sp15' => 2,
                         'Genus:sp20' => 4,
                         'Genus:sp23' => 1,
                         'Genus:sp24' => 1,
                         'Genus:sp25' => 1,
                         'Genus:sp26' => 2,
                         'Genus:sp27' => 1,
                         'Genus:sp29' => 1,
                         'Genus:sp30' => 1,
                         'Genus:sp5'  => 1
                       },
  'ABC2_LABELS_SET1' => {
                          'Genus:sp20' => 1,
                          'Genus:sp26' => 1
                        },
  'ABC2_LABELS_SET2' => {
                          'Genus:sp1'  => 2,
                          'Genus:sp10' => 1,
                          'Genus:sp11' => 2,
                          'Genus:sp12' => 2,
                          'Genus:sp15' => 2,
                          'Genus:sp20' => 3,
                          'Genus:sp23' => 1,
                          'Genus:sp24' => 1,
                          'Genus:sp25' => 1,
                          'Genus:sp26' => 1,
                          'Genus:sp27' => 1,
                          'Genus:sp29' => 1,
                          'Genus:sp30' => 1,
                          'Genus:sp5'  => 1
                        },
  'ABC2_MEAN_ALL'   => '1.57142857142857',
  'ABC2_MEAN_SET1'  => '1',
  'ABC2_MEAN_SET2'  => '1.42857142857143',
  'ABC2_SD_ALL'     => '0.85163062725264',
  'ABC2_SD_SET1'    => '0',
  'ABC2_SD_SET2'    => '0.646206172658864',
  'ABC3_LABELS_ALL' => {
                         'Genus:sp1'  => 8,
                         'Genus:sp10' => 16,
                         'Genus:sp11' => 9,
                         'Genus:sp12' => 8,
                         'Genus:sp15' => 11,
                         'Genus:sp20' => 12,
                         'Genus:sp23' => 2,
                         'Genus:sp24' => 2,
                         'Genus:sp25' => 1,
                         'Genus:sp26' => 6,
                         'Genus:sp27' => 1,
                         'Genus:sp29' => 5,
                         'Genus:sp30' => 1,
                         'Genus:sp5'  => 1
                       },
  'ABC3_LABELS_SET1' => {
                          'Genus:sp20' => 4,
                          'Genus:sp26' => 2
                        },
  'ABC3_LABELS_SET2' => {
                          'Genus:sp1'  => 8,
                          'Genus:sp10' => 16,
                          'Genus:sp11' => 9,
                          'Genus:sp12' => 8,
                          'Genus:sp15' => 11,
                          'Genus:sp20' => 8,
                          'Genus:sp23' => 2,
                          'Genus:sp24' => 2,
                          'Genus:sp25' => 1,
                          'Genus:sp26' => 4,
                          'Genus:sp27' => 1,
                          'Genus:sp29' => 5,
                          'Genus:sp30' => 1,
                          'Genus:sp5'  => 1
                        },
  'ABC3_MEAN_ALL'  => '5.92857142857143',
  'ABC3_MEAN_SET1' => '3',
  'ABC3_MEAN_SET2' => '5.5',
  'ABC3_SD_ALL'    => '4.89056054226736',
  'ABC3_SD_SET1'   => '1.4142135623731',
  'ABC3_SD_SET2'   => '4.63680924774785',
  'ABC3_SUM_ALL'   => 83,
  'ABC3_SUM_SET1'  => 6,
  'ABC3_SUM_SET2'  => 77,
  'ABC_A'          => 2,
  'ABC_ABC'        => 14,
  'ABC_B'          => 0,
  'ABC_C'          => 12,
  'ABC_D'          => 17,
  'COMPL'          => 14,
  'EL_COUNT_ALL'   => 5,
  'EL_COUNT_SET1'  => 1,
  'EL_COUNT_SET2'  => 4,
  'EL_LIST_ALL'    => [
                     '3250000:850000',
                     '3350000:850000',
                     '3350000:750000',
                     '3350000:950000',
                     '3450000:850000'
                   ],
  'EL_LIST_SET1' => {
                      '3350000:850000' => 1
                    },
  'EL_LIST_SET2' => {
                      '3250000:850000' => 1,
                      '3350000:750000' => 1,
                      '3350000:950000' => 1,
                      '3450000:850000' => 1
                    },
  'REDUNDANCY_ALL'  => '0.831325301204819',
  'REDUNDANCY_SET1' => '0.666666666666667',
  'REDUNDANCY_SET2' => '0.818181818181818',
  'RICHNESS_ALL'    => 14,
  'RICHNESS_SET1'   => 2,
  'RICHNESS_SET2'   => 14
}

@@ RESULTS_1_NBR_LISTS
{
  'ABC2_LABELS_SET1' => {
                          'Genus:sp20' => 1,
                          'Genus:sp26' => 1
                        },
  'ABC2_MEAN_ALL'    => '1',
  'ABC2_MEAN_SET1'   => '1',
  'ABC2_SD_SET1'     => '0',
  'ABC3_LABELS_SET1' => {
                          'Genus:sp20' => 4,
                          'Genus:sp26' => 2
                        },
  'ABC3_MEAN_SET1' => '3',
  'ABC3_SD_SET1'   => '1.4142135623731',
  'ABC3_SUM_SET1'  => 6,
  'ABC_D'          => 29,
  'EL_COUNT_SET1'  => 1,
  'EL_LIST_SET1'   => {
                      '3350000:850000' => 1
                    },
  'REDUNDANCY_ALL'  => '0.666666666666667',
  'REDUNDANCY_SET1' => '0.666666666666667',
  'RICHNESS_ALL'    => 2,
  'RICHNESS_SET1'   => 2
}