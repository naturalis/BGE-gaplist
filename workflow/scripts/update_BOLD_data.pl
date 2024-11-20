#!/usr/bin/perl -w
use strict;
use warnings;
use LWP::Simple; # for using get;


sub REMOVESPACE 
{
	my$name;
	my$backup;
	foreach(@_)
		{
			$name=$_;
			$backup=$_;
			$name=~s/  / /;
		}
	unless($backup eq $name)
		{
			print "too much space $backup\n";
		}	
	return $name;
}

unlink "../Raw_Data/BOLD_specieslist_europe/updated_BOLD_data.csv";
open(DAT,"<../Curated_Data/all_specs_and_syn.csv");
my$linecounter=0;
my%done;
my%no;
my$count;
while(<DAT>)
	{
		my$line=$_;
		$linecounter++;
		print "$linecounter\n";
		my@array=split(/;/,$line);

		foreach(@array)
			{
				#print "$_\n"if $_=~/\w\w*/;
				my$name=$_;
				chomp$name;
				$name=REMOVESPACE($name);
				$count++;
				print "	$count\n";
				if(defined $no{$name})
					{
						next
						
					}
				
				API:
				my $content = `GET "http://v3.boldsystems.org/index.php/API_Tax/TaxonSearch?taxName=$_"`;
				if(defined $content)
					{
						if($content=~/"taxid":([^,]*)/)
							{
								#print "$1\n";
								my$id=$1;
								if(defined $done{$id})
									{
										next;
									}

								my$barcodespec;
								my$specrec;
								my$publicbin;


								TAX:
								my $taxon = `GET "http://v3.boldsystems.org/index.php/API_Tax/TaxonData?taxId=$1&dataTypes=basic,stats"`;
								


								if(defined $taxon)
									{
										#print "$taxon\n";

										if($taxon=~/#kohana_error/)
											{
												next;
											}
										if($taxon=~/"barcodespecimens":"([^\"]*)"/)
											{
												$barcodespec=$1;
											}	
										if($taxon=~/.*specimenrecords":"([^\"]*)"/)
											{
												$specrec=$1;
											}
										if($taxon=~/.*"publicbins":([^\"]*),"/)
											{
												$publicbin=$1;
											}	
										if(defined $barcodespec)
											{
												open(OUT,">>updated_BOLD_data.csv");
												print OUT "$name;$id;$barcodespec;$specrec;$publicbin\n";
												print "$name;$id;$barcodespec;$specrec;$publicbin\n";
												close OUT;
											}	

									}
								else
									{
										my$rand=rand(3);
										sleep $rand;
										goto TAX
									}
								$done{$id}=1;	
							}
					}
				else
					{
						my$rand=rand(3);
						sleep $rand;
						goto API
					}	
			
			}

	}



