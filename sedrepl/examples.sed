# basic substitution: replace first occurrence of 'chr' with 'chromosome'
s/chr/chromosome/

# print only lines matching a pattern (use -n flag via #ARGS)
#/^chr8/p

# delete comment lines
#/^#/d

# delete blank lines
#/^$/d

# print the first field only (like 'cut -f1'; use -n flag via #ARGS)
#s/[[:space:]].*//
#p

# substitute on a range of lines (lines 2-4)
#2,4s/chr/CHR/

# multiple substitutions on the same line
#s/chr/CHR/
#s/^/PREFIX_/

# transform tabs to pipes
#s/\t/|/g

# only lines matching 'chr[XY]'
#/chr[XY]/s/rs[0-9]*/RSXXX/

# print lines 2 through end-of-file (use -n flag via #ARGS)
#2,$p

#DATA
chrX	69009356	69009357	rs911397765
chr1	178100230	178100232	rs142688086
chr2	106962156	106962157	rs554435669
chr4	15619267	15619268	rs555507240
chr5	33057721	33057722	rs889778604
chr6	54521349	54521350	rs138891996
chr8	11371770	11371771	rs1045871018
chr8	33647611	33647612	rs537033502
chr10	66908242	66908243	rs960484820
