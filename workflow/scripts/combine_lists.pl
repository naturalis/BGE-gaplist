#!/usr/bin/perl -w
use strict;
use warnings;


sub REMOVESPACE {
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
			#print "too much space $backup\n";
		}	
	return $name;
}
unlink "../Curated_Data/corrected_synonyms.csv";
my%syn;

open(SYN,"<../Curated_Data/basic_exclusion_list.csv");

### use basic exclusion list to correct synonyms and to exclude useless data

print "get basic_exclusion_list\n";


my%exclude; # hash for names that have to be excluded
my@globlist; # global list of species names
my%finished; # hash for flags that show, that a sample has been processed
my%reverse; # reverse synonymy relation
my%verif; # hash for the name of the verification step
while(<SYN>) # read the basic eclusion list
	{
		my$line=$_; 
		chomp$line; # remove line ending
		$line=REMOVESPACE($line);
		my@array=split(/\t/,$line); # split line at tabulator
		my$false=$array[0]; # assign the first column to the variable $false
		my$val=$array[1]; # variable to decidet to exclude or not
		if($val eq "e") # test variable for "e"
			{
				$exclude{$false}=1; # set excludion true for this species
			}
		my$synon=$array[2]; # 3rd column for the valid name
		chomp $synon;	# remove file ending 
		if($synon=~/\w/) # check if the variable contains letters
			{
				#print "$array[0] $array\n";
				if(defined $reverse{$synon}) # check if variable already exists
					{
						$reverse{$synon}="$reverse{$synon};$false"; # 
					}
				else
					{
						$reverse{$synon}="$false";
					}	
				$reverse{$synon}=$false unless $false eq $synon;
				$syn{$false}=$synon unless $false eq $synon;
				$verif{$synon}="BEL";
				push(@globlist,$false);
			}
	}
close SYN;

print "get Fauna Europaea synonyms\n";

open(SYN,"../Raw_Data/Fauna_Europaea/list_of_synonyms.csv");

while(<SYN>)
	{
		my$line=$_;
		chomp$line;
		$line=REMOVESPACE($line);
		if($line=~/^([^\;]*);([^\;]*)/)
			{
				my$false=$1;
				chomp$false;
				my$true=$2;
				#print $line if $true=~/Alcis/;
				
				if(defined $reverse{$false})
					{
						my@list=split(/;/,$reverse{$false});
						foreach(@list)
							{
								#print "	$_\n";
								$syn{$_}=$true;
								#$verif{$true}="FE";	
							}
					}	
				if(defined $reverse{$true})
					{
						$reverse{$true}="$reverse{$true};$false";
					}					
				else
					{
						$reverse{$true}=$false;
					}	
				$syn{$false}=$true unless $false eq $true;
				#print "$syn{$1}\n";
				$verif{$true}="FE";
				push(@globlist,$false);
 			}
	}



my$dir= "../Curated_Data/modified/";
my@files = glob( $dir . '/*.csv' );
@files=sort(@files);
unlink "../Curated_Data/multiple_synonyms.csv";
my%specfam;
my%expert_fam;
 foreach(@files)
	{
		open(SYN,"<$_");
		print "$_\n";
		
		while(<SYN>)
			{
				my$line=$_;
				$line=REMOVESPACE($line);
				#print $line;
				my@array=split(/\t/,$line);
				my$val=$array[1];
				chomp$val;
				my$false=$array[0];
				chomp $false;
				my$true=$array[2];
				chomp $true;
				my$var=$array[3];

				if(defined $array[5] && $array[5]=~/\w+/)
					{
						#print "$array[5]\n";
						chomp $array[5];
						$expert_fam{$true}=$array[5];
						$verif{$true}=$array[5];
						#$expert_fam{$false}=$array[5];
					}

				chomp$var;
				#print "$var\n";
				if($val eq "e")
					{
						$exclude{$array[0]}=1;
						next;
					}
				if($array[2]=~/\w/)
					{
						open(OUT,">>../Curated_Data/multiple_synonyms.csv");

					if(defined $reverse{$false})
						{
							print OUT "$false\n";
							my@list=split(/;/,$reverse{$false});
							foreach(@list)
								{
									print OUT "	$_\n";
									$syn{$_}=$true;
									#$verif{$true}=$var;
								}
							print OUT  "		$true\n"	
						}
					if(defined $reverse{$true})
						{
							$reverse{$true}="$reverse{$true};$false"
						}
					else
						{
							$reverse{$true}=$false;
						}						
					$syn{$false}=$true;	

						push(@globlist,$array[0]);
						$verif{$true}=$var
					}
close OUT;
	}
close SYN;
	}

my%BOLD;
my@speclist;
my%hyra;
my%done;

my%source;

# Additional data from experts

$dir= "../Raw_Data/Additional_data_from_experts";
@files = glob( $dir . '/*.csv' );
foreach(@files)
	{
	my$expert;	
		open(DAT,"<$_");

		my$filename=$_;
		print "$filename\n";
		if($filename=~/([^\_]*)\.csv/)
			{
				$expert=$1;
			}
 my%exp;

 my$flag=0;
 while(<DAT>)
 	{
 		my$line=$_;
  		chomp $line; 	
  		$line=REMOVESPACE($line);	
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="$expert";
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},$expert" unless defined $exp{$spec};
 				$exp{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="$expert"unless defined $exp{$spec};
 				$exp{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam unless defined $specfam{$spec};
				push(@speclist,$spec);
				$done{$spec}=1;
			}	
			$verif{$spec}="$expert";
			$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
close DAT;

	}

my%long;
my%short;
my%fail;


## BOLD

open(DAT,"<../Raw_Data/BOLD_specieslist_europe/21_11_2022_public_specieslist_BOLD.csv");
unlink ">>../Curated_Data/incomplete_taxonomy.csv";
unlink "../Curated_Data/excluded_names.csv";
open(EXN,">>../Curated_Data/excluded_names.csv");


while(<DAT>)
	{
 		my$line=$_;
 		chomp $line;
 		$line=REMOVESPACE($line);
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];



 		my$order=$head[2];
 		chomp $class;
 		chomp $order; 		
 		my$fam=$head[3];
 		chomp $fam;
 		my$spec=$head[4];
 		chomp$spec;



 		if(defined $exclude{$spec})
 			{
 					
 				print EXN "$spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec eq $syn{$spec};

 				print SYN "$spec;";
 				print SYN "$verif{$head[4]}"if defined $verif{$head[4]};
 				print SYN "\n";
 				close SYN;
 			}	
 		my$longseq=$head[5];
 		if(defined $long{$spec})
 			{
 				$long{$spec}=$long{$spec}+$longseq if $longseq=~/\d/;
 			}
 		else
 			{
				$long{$spec}=$longseq if $longseq=~/\d/;
 			}		
 		my$shortseq=$head[6];
 		if(defined $short{$spec})
 			{
 				$short{$spec}=$short{$spec}+$shortseq if $shortseq=~/\d/;
 			}	
 		else
 			{
 				$short{$spec}=$shortseq if $shortseq=~/\d/;
 			}	 		
 		my$failed=$head[7];
 		if(defined $fail{$spec})
 			{
 				$fail{$spec}=$fail{$spec}+$failed if $failed=~/\d/;
 			}	
 		else
 			{
 				$fail{$spec}=$failed if $failed=~/\d/;
 			}	 		

 		if($order eq "Heteroptera")
				{
					$order="Hemiptera";
				}
		if($fam eq "Heteronemiidae")
			{
				$order="Phasmatodea";
			}
		if($fam eq "Meinertellidae")
			{
				$order="Archaeognatha";
			} 			
		$hyra{$fam}="$phylum;$class;$order;$fam";
		$BOLD{$spec}="$phylum;$class;$order;$fam";
		$specfam{$spec}=$fam unless defined $specfam{$spec};
		$source{$spec}="BOLD";
		push(@speclist,$spec) unless $done{$spec};
		$done{$spec}=1;
	}
close DAT;

## BOLD Metadata not from the european list
open(DAT,"<../Raw_Data/BOLD_specieslist_europe/non_european_BOLD.csv");

while(<DAT>)
	{
 		my$line=$_;
 		chomp $line;
 		$line=REMOVESPACE($line);
 		my@head=split(/;/,$line);
 		my$spec=$head[0];
 		chomp$spec;

 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				#open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				#print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec eq $syn{$spec};

 				#print SYN "$spec;";
 				#print SYN "$verif{$head[4]}"if defined $verif{$head[4]};
 				#print SYN "\n";
 				#close SYN;
 			}	
 		my$longseq=$head[2];
 		if(defined $long{$spec})
 			{
 				$long{$spec}=$long{$spec}+$longseq if $longseq=~/\d/;
 			}
 		else
 			{
				$long{$spec}=$longseq if $longseq=~/\d/;
 			}		
 		my$shortseq=$head[3];
 		if(defined $short{$spec})
 			{
 				$short{$spec}=$short{$spec}+$shortseq if $shortseq=~/\d/;
 			}	
 		else
 			{
 				$short{$spec}=$shortseq if $shortseq=~/\d/;
 			}	 		
 		my$failed=$head[4];
 		if(defined $fail{$spec})
 			{
 				$fail{$spec}=$fail{$spec}+$failed if $failed=~/\d/;
 			}	
 		else
 			{
 				$fail{$spec}=$failed if $failed=~/\d/;
 			}	 		
	}
close DAT;
## Fauna Europaea
open(DAT,"<../Raw_Data/Fauna_Europaea/specieslist_FE.csv");
my%FE;
my%FEU;
while(<DAT>)
	{
 		my$line=$_;
 		chomp $line; 	
 		$line=REMOVESPACE($line);	
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];

 		my$order=$head[2];
 		chomp $class;
 		chomp $order;
 		my$fam=$head[3];
 		chomp $fam;
 		my$spec=$head[4];
 		chomp$spec;
 		if(defined $exclude{$spec})
 			{
 				print EXN "$spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				
 				print SYN "$spec;";

 				$spec=$syn{$spec} unless $spec eq $syn{$spec};
 				$verif{$spec}="FE" unless defined $verif{$spec};


 				#print "$spec";
 				#$syn{$spec}
 				print SYN "$spec\n";
 				close SYN;
 			}				
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},FE" unless defined $FE{$spec};
 				$FE{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="FE";
 				$FE{$spec}=1;
 			}	 		
 		if($order eq "Heteroptera")
				{
					$order="Hemiptera";
				}
		if($fam eq "Heteronemiidae")
			{
				$order="Phasmatodea";
			}
		if($fam eq "Meinertellidae")
			{
				$order="Archaeognatha";
			}			
		$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
		$FEU{$spec}="$phylum;$class;$order;$fam";
		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam unless defined $specfam{$spec};
				push(@speclist,$spec);
			}	
			$done{$spec}=1;
	}
 open(DAT,"<../Raw_Data/Lepiforum/specieslist_Lepiforum.csv");
 my%LEP;
 my%LF;
 my$flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		chomp $line; 	
 		$line=REMOVESPACE($line);	
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class;
 		my$order=$head[2];
 		chomp $order;
 		my$fam=$head[3];
 		chomp $fam;
 		my$spec=$head[4];
 		chomp$spec;

 		if(defined $exclude{$spec})
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="LF" unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},LF" unless defined $LF{$spec};
 				$LF{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="LF"unless defined $LF{$spec};
 				$LF{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam unless defined $specfam{$spec};
				push(@speclist,$spec);
			}	
			

			$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
### WORMS
#goto SKIP;
open(DAT,"<../Raw_Data/WORMS/specieslist_WORMS.csv");
 my%WORMS;
 #my%LF;
 $flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		#print $line;
 		chomp $line; 
 		$line=REMOVESPACE($line);		
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="WORMS" unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},WORMS" unless defined $WORMS{$spec};
 				$WORMS{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="WORMS"unless defined $WORMS{$spec};
 				$WORMS{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam unless defined $specfam{$spec};
				push(@speclist,$spec);
			}	
			

			
         if($class eq "Hexanauplia")
                {
                    $class="Copepoda";
                }
			
			$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
## Catalogue of Palearctic Heteroptera
open(DAT,"<../Raw_Data/Catalogue_of_Palearctic_Heteroptera/specieslist_CoPH.csv");
 my%CoPH;
 #my%LF;
 $flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		#print $line;
 		chomp $line; 
 		$line=REMOVESPACE($line);		
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="CoPH" unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},CoPH" unless defined $CoPH{$spec};
 				$CoPH{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="CoPH"unless defined $CoPH{$spec};
 				$CoPH{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam;
				push(@speclist,$spec);
			}	
			
			$specfam{$spec}=$fam unless defined $done{$spec};
			$hyra{$fam}="$phylum;$class;$order;$fam"; #unless defined $hyra{$fam};


			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
## iNaturalist
open(DAT,"<../Raw_Data/inaturalist_germany/speclist_inaturalist.csv");
 my%iNat;
 #my%LF;
 $flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		#print $line;
 		chomp $line;
 		$line=REMOVESPACE($line); 		
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="iNat" unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},iNat" unless defined $iNat{$spec};
 				$iNat{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="iNat"unless defined $iNat{$spec};
 				$iNat{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam;
				#push(@speclist,$spec);
			}	
			

			$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
close DAT; 	
# Reptile database
open(DAT,"<../Raw_Data/reptile-database/speclist_RDB.csv");
 my%RDB;
 
 $flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		#print $line;
 		chomp $line; 
 		$line=REMOVESPACE($line);		
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="RDB" unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},RDB" unless defined $RDB{$spec};
 				$RDB{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="RDB"unless defined $RDB{$spec};
 				$RDB{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam;
				push(@speclist,$spec);
			}	
			

			$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
close DAT;	
#Syrphidae.com 	
open(DAT,"<../Raw_Data/Syrphidae.com/speclist_Syrphidae.csv");
 my%Syr;
 
 $flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		#print $line;
 		chomp $line; 
 		$line=REMOVESPACE($line);		
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="Syr"unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},Syr" unless defined $Syr{$spec};
 				$Syr{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="Syr"unless defined $Syr{$spec};
 				$Syr{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam;
				push(@speclist,$spec);
			}	
			

			$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$Syr{$spec}="$phylum;$class;$order;$fam";
 	}
close DAT; 	
# Systema diptorum
open(DAT,"<../Raw_Data/Systema_Dipterorum/speclist_SyDip.csv");
 my%SyDip;
 #my%LF;
 $flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		#print $line;
 		chomp $line; 		
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="SyDip"unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},SyDip" unless defined $SyDip{$spec};
 				$SyDip{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="SyDip"unless defined $SyDip{$spec};
 				$SyDip{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam;
				#push(@speclist,$spec);
			}	
			

			$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
close DAT; 	
# Hymenoptera Information System
open(DAT,"<../Raw_Data/Hymenoptera_Information_System/speclist_HySI.csv");
 my%HySI;
 #my%LF;
 $flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		#print $line;
 		chomp $line;
 		$line=REMOVESPACE($line); 		
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="HySI"unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},HySI" unless defined $HySI{$spec};
 				$HySI{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="HySI"unless defined $HySI{$spec};
 				$HySI{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam;
				#push(@speclist,$spec);
			}	
			

			#$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
close DAT; 	
# DTN Diversity Taxon Names Insecta
open(DAT,"<../Raw_Data/DTN_insecta/speclist_DTN.csv");
 my%DTN;
 #my%LF;
 $flag=0;
 while(<DAT>)
 	{

 		my$line=$_;
 		#print $line;
 		chomp $line; 	
 		$line=REMOVESPACE($line);	
 		my@head=split(/;/,$line);
 		my$phylum=$head[0];
 		chomp $phylum;
 		my$class=$head[1];
 		chomp $class if defined $class;
 		my$order=$head[2];
 		chomp $order if defined $order;
 		my$fam=$head[3];
 		chomp $fam if defined $fam;
 		my$spec=$head[4];
 		chomp$spec if defined $spec;

 		if(defined $exclude{$spec} && defined $spec)
 			{
 				#print "exclude $spec\n";
 				next
 			}
 		if($spec=~/\w/)
 			{

 			}
 		else
 			{
 				next;
 			}	 		
 		if(defined $syn{$spec})
 			{
 				open(SYN,">>../Curated_Data/corrected_synonyms.csv");
 				print SYN "$spec;";
 				$spec=$syn{$spec} unless $spec=$syn{$spec};
 				$verif{$spec}="DTN"unless defined $verif{$spec};;
 				print SYN "$spec\n";
 				close SYN;
 			}	
 		if(defined $source{$spec})
 			{
 				$source{$spec}="$source{$spec},DTN" unless defined $DTN{$spec};
 				$DTN{$spec}=1;
 			}
 		else
 			{
 				$source{$spec}="DTN"unless defined $DTN{$spec};
 				$DTN{$spec}=1;
 			}	
 		unless (defined $done{$spec})
			{
				$specfam{$spec}=$fam;
				#push(@speclist,$spec);
			}	
			

			#$hyra{$fam}="$phylum;$class;$order;$fam" unless defined $hyra{$fam};
			#$hyra{$fam}="$phylum;$order;$class;$fam" if $hyra{$fam}=~/;;/;
			#$LEP{$spec}="$phylum;$class;$order;$fam";
 	}
close DAT;
my@sorted=sort@speclist;
my$count=0;
unlink "../Curated_Data/combined_species_lists.csv" if -e "../Curated_Data/combined_species_lists.csv";
open(OUT,">>../Curated_Data/combined_species_lists.csv");
unlink "../Curated_Data/exclusion_list.csv";
open (EXC,">>../Curated_Data/exclusion_list.csv");
print EXC "species;invalid;synonym;source;family;accepded family;\n";

system "rm -r ../Curated_Data/combined_list/" if -e "../Curated_Data/combined_list/";
system "mkdir ../Curated_Data/combined_list/";
my%dupl;

foreach(@sorted)
	{
		my$species=$_;
		chomp $species;
		$species=REMOVESPACE($species);
		$count++;
		if(defined $dupl{$species})
			{
				next;
			}
		$dupl{$species}=1;
		if($hyra{$specfam{$species}}=~/;;/)
			{
						open(MIS,">>../Curated_Data/incomplete_taxonomy.csv");
						print MIS "$species;$hyra{$specfam{$species}};$source{$species};\n" unless defined $done{$specfam{$species}};
						$done{$specfam{$species}}=1;
						close MIS ;
			}
		print EXC "$species;;;$source{$species};$specfam{$species};\n";	
		$specfam{$species}=$expert_fam{$species} if defined $expert_fam{$species};
		print OUT "$species;$hyra{$specfam{$species}};$source{$species};";
		if(defined $long{$species})
			{
				print OUT "$long{$species};";
			}
		else
			{
				print OUT ";"
			}	
		if(defined $short{$species})
			{
				print OUT "$short{$species};";
			}
		else
			{
				print OUT ";"
			}	
		if(defined $fail{$species})
			{
				print OUT "$fail{$species};";
			}
		else
			{
				print OUT ";"
			}
		if(defined $verif{$species})
			{
				print OUT "$verif{$species}\n";
			}
		else
			{									
				print OUT "\n";	
			}
		my@path=split(/;/,$hyra{$specfam{$species}});
		my$pathstr;
		
		my$part;
		my$counter=0;
		foreach(@path)
			{
				#if($counter>=3)
				#	{
				#		next;
				#	}
				$counter++;
				$part=$_;
				chomp $part;
				if($part =~ s/ /_/g)
					{
						
						#print $part;
					}
				unless(defined $pathstr)
					{
						$pathstr="../Curated_Data/combined_list/$part";
						system "mkdir $pathstr"unless -e "$pathstr";
					}
				else
					{
						$pathstr="$pathstr/$part";
						system "mkdir $pathstr"unless -e "$pathstr";
					}	
			}
		open(WRI,">>$pathstr/$part.csv");
		print WRI "$species;$hyra{$specfam{$species}};$source{$species};";
		if(defined $long{$species})
			{
				print WRI "$long{$species};";
			}
		else
			{
				print WRI ";"
			}
		if(defined $short{$species})
			{
				print WRI "$short{$species};";
			}
		else
			{
				print WRI ";"
			}	
		if(defined $fail{$species})
			{
				print WRI "$fail{$species};";
			}
		else
			{
				print WRI ";"
			}					
		print WRI "\n";	
		close WRI;	

	}
close OUT;	
print "\n$count\n";


close EXN;



unlink "../Curated_Data/all_specs_and_syn.csv";
open(OUT,">>../Curated_Data/all_specs_and_syn.csv");
 foreach(@speclist)
 	{
 		my$name=$_;
 		if(defined $reverse{$name})
 			{
 				print OUT "$name;";
 				my%gotit;
 				my@array=split(/;/,$reverse{$name});
 				foreach(@array)
 					{
 						print OUT "$_;" unless defined $gotit{$_};
 						$gotit{$_}=1;
 					}
 			}
 		else
 			{
 				print OUT "$name;"
 			}	
 		print OUT "\n";	
 	}
 close OUT;	


