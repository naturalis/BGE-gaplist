#!/usr/bin/perl -w
use strict;
use warnings;

my%value;
open(DAT,"<../Curated_Data/23_07_2024_updated_BOLD_data.csv");
while(<DAT>){
	my$line=$_;
	chomp$line;
	my@array=split(";",$line);
	$value{$array[0]}{"specbar"}=$array[2];
	$value{$array[0]}{"spec"}=$array[3];
	$value{$array[0]}{"BINs"}=$array[4];
}

close DAT;

open(DAT,"<../Curated_Data/combined_species_lists.csv");
unlink "../Curated_Data/updated_combined_lists.csv";
open(OUT,">>../Curated_Data/updated_combined_lists.csv");
while(<DAT>) {
	my$line=$_;
	chomp$line;
	my@array=split(";",$line);
	my$length=@array;
	print OUT "$array[0];$array[1];$array[2];$array[3];$array[4];$array[5];";
	if(defined $value{$array[0]}{'specbar'}) {
		print OUT "$value{$array[0]}{'specbar'}";
	}
	print OUT";";
	if(defined $value{$array[0]}{'spec'}) {
		print OUT "$value{$array[0]}{'spec'}";
	}
	print OUT";";
	if(defined $value{$array[0]}{'BINs'}) {
		print OUT "$value{$array[0]}{'BINs'}";
	}
	print OUT";";	
	if(exists $array[9]) {
		for (my $var = 9; $var < $length; $var++){
			print OUT "$array[$var]";	
		}
	}

	print OUT "\n";
}