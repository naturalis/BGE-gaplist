#!/usr/bin/perl -w


# 

#use Spreadsheet::WriteExcel;

unlink "time.txt" if -e "time.txt";

system "date -I > time.txt";

open(TIM,"<time.txt");
my$date;                                                   
while(<TIM>)
	{
		my$line=$_;
		chomp$line;
		if($line=~/\d\d*/)
			{
				$date=$line;
			}

	}
unlink "time.txt";	

unlink "../Gap_Lists/Gap_list_all.csv";

open(OUT,">>../Gap_Lists/Gap_list_all.csv");
open(DAT,"<../Curated_Data/updated_combined_lists.csv");
#open(DAT,"<../Curated_Data/combined_species_lists.csv");

#open(SPE,"<gbif_species_identifier.csv");

my%gbif;

# while(<SPE>)
# 	{
# 		my$line=$_;
# 		if($line=/(^[^,]*),(.*)$/)
# 			{
# 				#print "$1\n$2\n";
# 				$gbif{$1}=$2;
# 			}
# 	}
# close SPE;

open(SPE,"<../Curated_Data/all_syn_BOLD_IDs.csv");
my%BOLDID;
while(<SPE>)
	{
		my$line=$_;
		chomp$line;
		if($line=~/(^[^,]*),(.*)$/)
			{
				#print "$1\n$2\n";
				$BOLDID{$1}=$2;
			}

	}
close SPE;

my@famlist;
my%done;
my%meta;
my%tax;
my%verif;
my%ord;
my%phy;
my%cla;
while(<DAT>)
	{
		my$line=$_;
		chomp$line;
		#print "$line\n";
		my@array=split(/;/,$line);

		my$spec=$array[0];
		my$phy=$array[1];
		my$cla=$array[2];
		chomp$cla;
		#$cla=s/\s/_/g;
		my$ord=$array[3];
		#chomp$ord;
		$ord=~s/\s/_/g;
		my$fam=$array[4];
		$fam=~s/\s/_/g;
		my$source=$array[5];
		my$lon=$array[6];
		my$sho=$array[7];
		my$fai=$array[8];
		my$verif=$array[9];
		$verif{$spec}=$verif;
		$meta{$spec}=$line;

#		if($source=~/BOLD/)
#			{
		if(defined $lon && $lon=~/\d/)
			{
				if ($spec=~/dispersopilosus/){print "yes\n"}
				if($lon ne "0")
					{
						$meta{$spec}="$meta{$spec};;";
						
					}
				else
					{	
						#print $lon;
						$meta{$spec}="$meta{$spec};gap;";	
					}	
			}
		else
			{

				$meta{$spec}="$meta{$spec};gap;";
			}	
		if(defined $tax{$fam})
			 {
			 	$tax{$fam}="$tax{$fam};$spec";
			 }
		else
			{
				$tax{$fam}=$spec;
			}	

		if($phy=~/^\w.*/)
			{	
				$phy{$fam}=$phy;	
			}
		else
			{
				$phy{$fam}="no_phylum_assigned"unless defined $phy{$fam};
			}				 

		if($cla=~/^\w.*/)
			{	
				$cla{$fam}=$cla;	
			}
		else
			{
				$cla{$fam}="no_class_assigned" unless defined $cla{$fam};
			}	
		if($ord=~/^\w.*/)
			{	
				$ord{$fam}=$ord;	
			}
		else
			{
				$ord{$fam}="no_order_assigned" unless defined $ord{$fam};
			}	

		push(@famlist,$fam) unless defined $done{$fam};
		$done{$fam}=1;
	}
my$flag=0;	
system "rm -r ../Gap_Lists/sorted" if -e "../Gap_Lists/sorted" ;
system "rm -r ../Gap_Lists/sorted_excel" if -e "../Gap_Lists/sorted_excel" ;
system "mkdir ../Gap_Lists/sorted"; 
system "mkdir ../Gap_Lists/sorted_excel";	
my@filelist;
foreach(@famlist)
	{
		print OUT"\n" unless $flag==0;
		$flag=1;
		print OUT "$_\n";
		
		my$fam=$_;
		#print"$ord{$fam}\n";


		system "mkdir ../Gap_Lists/sorted/$phy{$fam}" unless -e "../Gap_Lists/sorted/$phy{$fam}"; 
		system "mkdir ../Gap_Lists/sorted/$phy{$fam}/$cla{$fam}" unless -e "../Gap_Lists/sorted/$phy{$fam}/$cla{$fam}";
		system "mkdir ../Gap_Lists/sorted/$phy{$fam}/$cla{$fam}/$ord{$fam}" unless -e "../Gap_Lists/sorted/$phy{$fam}/$cla{$fam}/$ord{$fam}";

		system "mkdir ../Gap_Lists/sorted_excel/$phy{$fam}" unless -e "../Gap_Lists/sorted_excel/$phy{$fam}"; 
		system "mkdir ../Gap_Lists/sorted_excel/$phy{$fam}/$cla{$fam}" unless -e "../Gap_Lists/sorted_excel/$phy{$fam}/$cla{$fam}";
		system "mkdir ../Gap_Lists/sorted_excel/$phy{$fam}/$cla{$fam}/$ord{$fam}" unless -e "../Gap_Lists/sorted_excel/$phy{$fam}/$cla{$fam}/$ord{$fam}";


		open(FAM,">>../Gap_Lists/sorted/$phy{$fam}/$cla{$fam}/$ord{$fam}/$date\_$fam.csv");
		
		push(@filelist,"$phy{$fam}/$cla{$fam}/$ord{$fam}/$date\_$fam") unless defined $done{"$phy{$fam}/$cla{$fam}/$ord{$fam}/$fam"};
		$done{"$phy{$fam}/$cla{$fam}/$ord{$fam}/$fam"}=1;

		print FAM "species;Phylum;Class;Order;Family;source;speciemens barcoded;speciemens;public BINs;verified by;status;BOLD taxid\n";
		@array=split(/;/,$tax{$fam});
		@array=sort@array;
		foreach(@array)
			{
				if(defined $BOLDID{$_})
					{
						my$identifier;
						my@array=split(/,/,$BOLDID{$_});
						foreach(@array)
							{
								my$id=$_;
								if(defined $identifier)
									{
										$identifier="$identifier;$_" unless defined $done{$_};
										$done{$_}=1;
									}
								else
									{
										$identifier="$id";
										$done{$id}=1;
									}	
							}

						print OUT "$meta{$_}$identifier\n";
						print FAM "$meta{$_}$identifier\n";


						#print OUT "$meta{$_}$gbif{$_}\n";
						#print FAM "$meta{$_}$gbif{$_}\n";
					}	
				# if(defined $gbif{$_})
				# 	{
				# 		my$identifier;
				# 		my@array=split(/,/,$gbif{$_});
				# 		foreach(@array)
				# 			{
				# 				my$id=$_;
				# 				if(defined $identifier)
				# 					{
				# 						$identifier="$identifier;$_";
				# 					}
				# 				else
				# 					{
				# 						$identifier=$id;
				# 					}	
				# 			}
				# 		print OUT "$meta{$_}$identifier\n";
				# 		print FAM "$meta{$_}$identifier\n";	
				# 		#print OUT "$meta{$_}$gbif{$_}\n";
				# 		#print FAM "$meta{$_}$gbif{$_}\n";
				# 	}

				else
					{
						print OUT "$meta{$_}\n";
						print FAM "$meta{$_}\n";						
					}	
			}
		close FAM;	
	}	

#foreach(@filelist)
#	{
		#print "$_\n";
#		system "cp ../Gap_Lists/sorted/$_.csv ../Gap_Lists/sorted_excel/$_.txt && ssconvert ../Gap_Lists/sorted_excel/$_.txt ../Gap_Lists/sorted_excel/$_.csv && ssconvert ../Gap_Lists/sorted_excel/$_.csv ../Gap_Lists/sorted_excel/$_.xls";
#		system "rm ../Gap_Lists/sorted_excel/$_.txt";
#	}

#ssconvert --export-type=Gnumeric_stf:stf_csv Gap_list_all.csv Gap_list_all.xls


