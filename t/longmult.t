#!/usr/bin/env perl

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use Cwd;
use File::Basename;

use Test::More;
use Data::Dumper;
use File::Temp qw{tempdir};

use Bio::EnsEMBL::Hive::Utils ('find_submodules');
use Bio::EnsEMBL::Hive::Utils::Test qw(init_pipeline);

# eHive needs this to initialize the pipeline (and run db_cmd.pl)
BAIL_OUT('$EHIVE_ROOT_DIR must be defined !') unless $ENV{'EHIVE_ROOT_DIR'};

my $dir = tempdir CLEANUP => 1;
my $original = chdir $dir;

my $ehive_test_pipeline_urls = $ENV{'EHIVE_TEST_PIPELINE_URLS'} || 'sqlite:///ehive_test_pipeline_db';

my @pipeline_urls = split( /[\s,]+/, $ehive_test_pipeline_urls ) ;
my @pipeline_cfgs = qw(LongMult_conf);

foreach my $long_mult_version ( @pipeline_cfgs ) {

    warn "\nInitializing the $long_mult_version pipeline ...\n\n";

    foreach my $pipeline_url (@pipeline_urls) {
            # override the 'take_time' PipelineWideParameter in the loaded HivePipeline object to make the internal test Worker run quicker:
        my $url         = init_pipeline(
                            ($long_mult_version =~ /::/ ? $long_mult_version : 'Bio::EnsEMBL::Hive::Examples::LongMult::PipeConfig::'.$long_mult_version),
                            [-pipeline_url => $pipeline_url, -hive_force_init => 1],
                            ['pipeline.param[take_time]=0', 'analysis[take_b_apart].meadow_type=undef'],
                        );

        my $pipeline = Bio::EnsEMBL::Hive::HivePipeline->new(
            -url                        => $url,
            -disconnect_when_inactive   => 1,
        );
        my $hive_dba    = $pipeline->hive_dba;

        my @beekeeper_cmd = ($ENV{'EHIVE_ROOT_DIR'}.'/scripts/beekeeper.pl', -url => $hive_dba->dbc->url, -sleep => 10, '-loop');
        system(@beekeeper_cmd);
        ok(!$?, 'beekeeper exited with the return code 0');

        is(scalar(@{$hive_dba->get_AnalysisJobAdaptor->fetch_all("status != 'DONE'")}), 0, 'All the jobs could be run');

        is(scalar(@{$hive_dba->get_WorkerAdaptor->fetch_all("meadow_type != 'SGE'")}), 0, 'All the workers were run under the SGE meadow');

        my $final_result_nta = $hive_dba->get_NakedTableAdaptor( 'table_name' => 'final_result' );
        my $final_results = $final_result_nta->fetch_all();

        is(scalar(@$final_results), 3, 'There are exactly 3 final_results');
        foreach ( @$final_results ) {
            ok( $_->{'a_multiplier'}*$_->{'b_multiplier'} eq $_->{'result'},
                sprintf("%s*%s=%s", $_->{'a_multiplier'}, $_->{'b_multiplier'}, $_->{'result'}) );
        }

        system( @{ $hive_dba->dbc->to_cmd(undef, undef, undef, 'DROP DATABASE') } );
    }
}

done_testing();

chdir $original;

