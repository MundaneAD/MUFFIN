#!/usr/bin/env nextflow
nextflow.enable.dsl=2

start_var = Channel.from("""
*********Start running MUFFIN*********
MUFFIN is a hybrid assembly and differential binning workflow for metagenomics, transcriptomics and pathway analysis.

If you use MUFFIN for your research pleace cite:

https://www.biorxiv.org/content/10.1101/2020.02.08.939843v1 

or

Van Damme R., Hölzer M., Viehweger A., Müller B., Bongcam-Rudloff E., Brandt C., 2020
"Metagenomics workflow for hybrid assembly, differential coverage binning, transcriptomics and pathway analysis (MUFFIN)",
doi: https://doi.org/10.1101/2020.02.08.939843 
**************************************
""")
start_var.view()

if (params.help) { exit 0, helpMSG() }

// Help Message
def helpMSG() {
    log.info """
    *********hybrid assembly and differential binning workflow for metagenomics, transcriptomics and pathway analysis*********

    MUFFIN is still under development please wait until the first non edge version realease before using it.
    Please cite us using https://www.biorxiv.org/content/10.1101/2020.02.08.939843v1

    Mafin is composed of 3 part the assembly of potential metagenome assembled genomes (MAGs); the classification of the MAGs; and the annotation of the MAGs.

        Usage example:
    nextflow run main.nf --ont nanopore/ --illumina illumina/ --assembler metaspades --rna rna/ -profile docker
    or 
    nextflow run main.nf --ont nanopore/ --illumina illumina/ --assembler metaflye -profile docker

        Input:
    --ont                       path to the directory containing the nanopore read file (fastq) (default: $params.ont)
    --illumina                  path to the directory containing the illumina read file (fastq) (default: $params.illumina)
    --rna                       path to the directory containing the RNA-seq read file (fastq) (default: none)
    --bin_classify              path to the directory containing the bins files to classify (default: none)
    --bin_annotate              path to the directory containing the bins files to annotate (default: none)
    --assembler                 the assembler to use in the assembly step (default: $params.assembler)

        Optional input:
    --check_db                  path to the checkm database
    --check_tar_db              path to the checkm database tar compressed
    --sourmash_db               path to the LCA database for sourmash (default: GTDB LCA formated)
    --eggnog_db                 path to the eggNOG database

        Output:
    --output                    path to the output directory (default: $params.output)

        Outputed files:
        You can see the output structure at https://osf.io/a6hru/
    QC                          The reads file after qc
    Assembly                    The assembly contigs file 
    Bins                        The bins produced by CONCOCT, MetaBAT2, MaxBin2 and MetaWRAP (the refining of bins)
    Mapped bin reads            The fastq files containing the reads mapped to each metawrap bin
    Unmapped bin reads          The fastq files containing the unmmaped reads of illumina and nanopore
    Reassembly                  The reassembly files of the bins (.fa and .gfa)
    Checkm                      Various file outputed by CheckM (summary, taxonomy, plots and output dir)
    Sourmash                    The classification done by sourmash
    Classify summary            The summary of the classification and quality control of the bins (csv file)
    RNA output                  The de novo assembled transcript and the quantification by Salmon
    Annotation                  The annotations files from eggNOG (tsv format)
    Parsed output               HTML files that summarize the annotations and show graphically the pathways


    

        Basic Parameter:
    --cpus                      max cores for local use [default: $params.cpus]
    --memory                    80% of available RAM in GB for --metamaps [default: $params.memory]


        Workflow Options:
    --skip_ill_qc               skip quality control of illumina files
    --skip_ont_qc               skip quality control of nanopore file
    --short_qc                  minimum size of the reads to be kept (default: $params.short_qc )
    --filtlong                  use filtlong to improve the quality furthermore (default: false)
    --model                     the model medaka will use (default: $params.model)
    --polish_iteration          number of iteration of pilon in the polish step (default: $params.polish_iteration)
    --extra_ill                 a list of additional ill sample file (with full path with a * instead of _R1,2.fastq) to use for the binning in Metabat2 and concoct
    --extra_ont                 a list of additional ont sample file (with full path) to use for the binning in Metabat2 and concoct
    --skip_metabat2             skip the binning using metabat2 (advanced)
    --skip_maxbin2              skip the binning using maxbin2 (advanced)
    --skip_concoct              skip the binning using concoct (advanced)

        Nextflow options:
    -profile                    change the profile of nextflow both the engine and executor more details on github README
    -resume                     resume the workflow where it stopped
    -with-report rep.html       cpu / ram usage (may cause errors)
    -with-dag chart.html        generates a flowchart for the process tree
    -with-timeline time.html    timeline (may cause errors)
    """
}

XX = "21"
YY = "04"
ZZ = "0"

if ( nextflow.version.toString().tokenize('.')[0].toInteger() < XX.toInteger() ) {
println "\033[0;33mporeCov requires at least Nextflow version " + XX + "." + YY + "." + ZZ + " -- You are using version $nextflow.version\u001B[0m"
exit 1
}
else if ( nextflow.version.toString().tokenize('.')[1].toInteger() == XX.toInteger() && nextflow.version.toString().tokenize('.')[1].toInteger() < YY.toInteger() ) {
println "\033[0;33mporeCov requires at least Nextflow version " + XX + "." + YY + "." + ZZ + " -- You are using version $nextflow.version\u001B[0m"
exit 1
}


    //*************************************************
    // STEP 0 Loading modules and workflow profile error handling
    //*************************************************

    // Error handling
    if ( workflow.profile == 'standard' ) { exit 1, "NO VALID EXECUTION PROFILE SELECTED, use e.g. [-profile local,docker]" }

    if (
    workflow.profile.contains('singularity') ||
    workflow.profile.contains('docker') ||
    workflow.profile.contains('conda')
    ) { "engine selected" }
    else { exit 1, "No engine selected:  -profile EXECUTER,ENGINE" }

    if (
    workflow.profile.contains('local') ||
    workflow.profile.contains('sge') ||
    workflow.profile.contains('slurm') ||
    workflow.profile.contains('gcloud') ||
    workflow.profile.contains('ebi') ||
    workflow.profile.contains('lsf') ||
    workflow.profile.contains('git_action')
    ) { "executer selected" }
    else { exit 1, "No executer selected:  -profile EXECUTER,ENGINE" }


    //module for assemble
    if (params.modular=="full" | params.modular=="assemble" | params.modular=="assem-class" | params.modular=="assem-annot") {
        include {sourmash_download_db} from './modules/sourmashgetdatabase'
        include {checkm_setup_db} from './modules/checkmsetupDB'
        include {checkm_download_db} from './modules/checkmgetdatabases'

        // gate1
        //include {discard_short} from './modules/ont_qc' params(short_qc : params.short_qc)
        //include {filtlong} from './modules/ont_qc' params(short_qc : params.short_qc)
        include {chopper} from './module/ont_qc' param(output : params.short_qc)
        include {merge} from './modules/ont_qc' params(output : params.output)
        include {fastp} from './modules/fastp' params(output : params.output) // simple QC done by fastp

        // gate2
        include {spades} from './modules/spades' params(output : params.output)
        include {spades_short} from './modules/spades' param(output : params.output)
        include {flye} from './modules/flye' params(output : params.output)
        include {minimap_polish} from'./modules/minimap2'
        include {racon} from './modules/polish'
        include {medaka} from './modules/polish' params(model : params.model)
        include {pilon} from './modules/polish' params(output : params.output)
        include {minimap2} from './modules/minimap2' //mapping for the binning 
        include {extra_minimap2} from './modules/minimap2'
        include {bwa} from './modules/bwa' //mapping for the binning
        include {extra_bwa} from './modules/bwa'

        //gate3
        include {metabat2_extra} from './modules/metabat2' params(output : params.output)    
        include {metabat2} from './modules/metabat2' params(output : params.output)
        include {contig_list} from './modules/list_ids'
        include {cat_all_bins} from './modules/cat_all_bins'
        include {bwa_bin} from './modules/bwa'  
        include {minimap2_bin} from './modules/minimap2'
        include {reads_retrieval} from './modules/seqtk_retrieve_reads' params(output : params.output)
        include {unmapped_retrieve} from './modules/seqtk_retrieve_reads' params(output : params.output)
    }
    //module for classify
    if (params.modular=="full" | params.modular=="classify" | params.modular=="assem-class" | params.modular=="class-annot") {

        //module for Bin quality control & classify
        include {checkm} from './modules/checkm'params(output : params.output)
        include {sourmash_bins} from './modules/sourmash'params(output : params.output)
        include {sourmash_checkm_parser} from './modules/checkm_sourmash_parser'params(output: params.output)
    }
    if (params.modular=="classify" | params.modular=="class-annot") {
        include {sourmash_download_db} from './modules/sourmashgetdatabase'
        include {checkm_setup_db} from './modules/checkmsetupDB'
        include {checkm_download_db} from './modules/checkmgetdatabases'
    }
    //module for annotate
    if (params.modular=="full" | params.modular=="annotate" | params.modular=="assem-annot" | params.modular=="class-annot") {
        //modules for annotate
        include {eggnog_download_db} from './modules/eggnog_get_databases'
        include {eggnog_bin} from './modules/eggnog'params(output : params.output)

        // modules (optionnal for RNA-Seq)
        include {fastp_rna} from './modules/fastp'params(output : params.output)
        include {de_novo_transcript_and_quant} from './modules/trinity_and_salmon'params(output : params.output)
        include {eggnog_rna} from './modules/eggnog'params(output : params.output)

        // module for outputs
        include {parser_bin_RNA} from './modules/parser'params(output: params.output)
        include {parser_bin} from './modules/parser'params(output: params.output)
    }
    include {readme_output} from './modules/readme_output'params(output: params.output)
    include {test} from './modules/test_data_dll'

    //*************************************************
    // STEP 1 Assemble using hybrid method
    //*************************************************

workflow { //start of the workflow
    if (params.modular=="full" | params.modular=="assemble" | params.modular=="assem-class" | params.modular=="assem-annot") { //only do the step one if called
        if (params.assembler!='metaflye' && params.assembler!='metaspades') { //check if the assembler parameter is correct
            exit 1, "--assembler: ${params.assembler}. Should be 'metaflye' or 'metaspades' (default: metaflye)"}

        // stdout early usage (print header + default or modified params)

        // DATA INPUT TEST
        if (workflow.profile.contains('test')) {

            test()
            illumina_input_ch = test.out[0]
            ont_input_ch = test.out[1]
            rna_input_ch = test.out[2]
        }

        else {
            if (workflow.profile.contains('long')){
                // DATA INPUT Oxforf nanopore technologies
                //************
                // ONT reads
                //************
                ont_input_ch = Channel.fromPath("${params.ont}/*.fastq{,.gz}",checkIfExists: true).map {file -> tuple(file.simpleName, file) }.view()

                // QC check ONT
                //if (params.skip_ont_qc == true) {}
                if (params.skip_ont_qc == true) {}
                else {
                    split_ont_ch = ont_input_ch.splitFastq(by:100000, file:true) //split the fastq to speed up the process
                    //discard_short(split_ont_ch) // simply discard the reads under a threshold
                    chopper(split_ont_ch)
                    merging_ch = chopper.out.groupTuple()
                    merge(merging_ch) // merge the splitted fastq
                    ont_input_ch = merge.out
                }
            }
            else if(workflow.profile.contains('short')){
                // DATA INPUT ILLUMINA
                //***************
                // Illumina reads
                //***************
                illumina_input_ch = Channel
                        .fromFilePairs( "${params.illumina}/*_R{1,2}.fastq{,.gz}", checkIfExists: true)
                        .view() 

                // QC check Illumina
                //if (params.skip_ill_qc==true) {}
                if (params.skip_ill_qc) {}
                else {
                    fastp(input_ch)
                    illumina_input_ch = fastp.out
                }
            }
            else {
                //hybrid method
                // DATA INPUT Oxforf nanopore technologies
                //************
                // ONT reads
                //************
                ont_input_ch = Channel.fromPath("${params.ont}/*.fastq{,.gz}",checkIfExists: true).map {file -> tuple(file.simpleName, file) }.view()

                // QC check ONT
                //if (params.skip_ont_qc == true) {}
                if (params.skip_ont_qc == true) {}
                else {
                    split_ont_ch = ont_input_ch.splitFastq(by:100000, file:true) //split the fastq to speed up the process
                    //discard_short(split_ont_ch) // simply discard the reads under a threshold
                    chopper(split_ont_ch)
                    merging_ch = chopper.out.groupTuple()
                    merge(merging_ch) // merge the splitted fastq
                    ont_input_ch = merge.out
                }
                // DATA INPUT ILLUMINA
                //***************
                // Illumina reads
                //***************
                illumina_input_ch = Channel
                        .fromFilePairs( "${params.illumina}/*_R{1,2}.fastq{,.gz}", checkIfExists: true)
                        .view() 

                // QC check Illumina
                //if (params.skip_ill_qc==true) {}
                if (params.skip_ill_qc) {}
                else {
                    fastp(input_ch)
                    illumina_input_ch = fastp.out
                }
            }

        }


        // sourmash_db
        if (params.sourmash_db) { database_sourmash = file(params.sourmash_db) } //use the path to the sourmash DB
        else {
            sourmash_download_db() 
            database_sourmash = sourmash_download_db.out
        }   
        // checkm_db
        if (workflow.profile.contains('conda') ) { // when using conda checkm needs to be set up first before any use
            if (params.checkm_db) { // this one set in the env the path to checkm db uncompressed
                untar = true
                checkm_setup_db(params.checkm_db, untar)
                checkm_db_path = checkm_setup_db.out
            }

            else if (params.checkm_tar_db) { // untar the checkm db before setting up
                untar = false
                checkm_setup_db(params.checkm_db, untar)
                checkm_db_path = checkm_setup_db.out
            }

            else { // DLL the check db , untar then setup
                untar = false
                checkm_setup_db(checkm_download_db(), untar)
                checkm_db_path = checkm_setup_db.out
            }
        }
        else { checkm_db_path = Channel.from("/checkm_database").collectFile() { item -> [ "path.txt", item ]  } } // Docker way to setup the db

        

        

        //**********
        // Assembly 
        //**********
        if(workflow.profile.contains('long')){
            //spades not for long reads
            // FLYE + Pilon 
            flye(ont_input_ch)
            assembly_ch = flye.out
        }
        else if (workflow.profile.contains('short')){
            //fly not for long reads
            //spades_short
            spades_ch = illumina_input_ch
            spades(spades_ch)
            assembly_ch = spades.out
        }
        else{
            // Meta-SPADES

            if (params.assembler=="metaspades") { // hybrid and metagenomic assembly by spades
                spades_ch= illumina_input_ch.join(ont_input_ch)
                spades(spades_ch)
                assembly_ch = spades.out
            }

                // Meta-FLYE

            if (params.assembler=="metaflye") { // metagenomic assembly by flye + hybrid polishing (combo racon; medaka; pilon with short reads)
                // FLYE + Pilon 
                flye(ont_input_ch)
                flye_to_map = flye.out.join(ont_input_ch)
                minimap_polish(flye_to_map)
                map_to_racon = ont_input_ch.join(flye.out).join(minimap_polish.out)
                medaka(racon(map_to_racon))
                medaka_to_pilon = medaka.out.join(illumina_input_ch)
                pilon(medaka_to_pilon, params.polish_iteration)
                assembly_ch = pilon.out
            }
        }

            

        //*********
        // Mapping
        //*********

        if(workflow.profile.contains('long')){
            // ONT mapping
            minimap2_ch = assembly_ch.join(ont_input_ch)
            minimap2(minimap2_ch)
            ont_bam_ch = minimap2.out

            if (params.extra_ont != false) { //mapping of the "additionnal reads" to the assembly for use in the differential coverage binning
                minimap_extra = assembly_ch.join(extra_ont_ch)
                extra_minimap2(minimap_extra)
                ont_extra_bam = extra_minimap2.out.collect()
            }
        }
        else if(workflow.profile.contains('short')){
            // Illumina mapping
            bwa_ch = assembly_ch.join(illumina_input_ch)
            bwa(bwa_ch)
            illumina_bam_ch = bwa.out

            if (params.extra_ill != false) { //mapping of the "additionnal reads" to the assembly for use in the differential coverage binning
                bwa_extra = assembly_ch.join(extra_ill_ch)
                extra_bwa(bwa_extra)
                illumina_extra_bam = extra_bwa.out.collect()
            }
        }
        else{

            // ONT mapping
            minimap2_ch = assembly_ch.join(ont_input_ch)
            minimap2(minimap2_ch)
            ont_bam_ch = minimap2.out

            if (params.extra_ont != false) { //mapping of the "additionnal reads" to the assembly for use in the differential coverage binning
                minimap_extra = assembly_ch.join(extra_ont_ch)
                extra_minimap2(minimap_extra)
                ont_extra_bam = extra_minimap2.out.collect()
            }

            // Illumina mapping
            bwa_ch = assembly_ch.join(illumina_input_ch)
            bwa(bwa_ch)
            illumina_bam_ch = bwa.out

            if (params.extra_ill != false) { //mapping of the "additionnal reads" to the assembly for use in the differential coverage binning
                bwa_extra = assembly_ch.join(extra_ill_ch)
                extra_bwa(bwa_extra)
                illumina_extra_bam = extra_bwa.out.collect()
            }
        }

        //***************************************************
        // Binning
        //***************************************************

            // metabat2 

        if (params.skip_metabat2==true) {}
        else {
            if (params.extra_ont != false || params.extra_ill != false ) { // check if differential coverage binning possible
                metabat2_ch = assembly_ch.join(ont_bam_ch).join(illumina_bam_ch)
                metabat2_extra(metabat2_ch, extra_bam)
                metabat2_out = metabat2_extra.out
            }
            else {
                metabat2_ch = assembly_ch.join(ont_bam_ch).join(illumina_bam_ch)
                metabat2(metabat2_ch)
                metabat2_out = metabat2.out
            }
        }

            // Maxbin2 

        if (params.skip_maxbin2==true) {}
        else {
            maxbin2_ch = assembly_ch.join(ont_input_ch).join(illumina_input_ch)
            maxbin2(maxbin2_ch)
            maxbin2_out = maxbin2.out
        }

            // Concoct OR CheckM Concoct

        if (params.skip_concoct==true) {}
        else {
            if (params.extra_ont != false || params.extra_ill != false ) { // check if differential coverage binning possible
                concoct_ch = assembly_ch.join(ont_bam_ch).join(illumina_bam_ch)
                concoct_extra(concoct_ch, extra_bam)
                concoct_out = concoct_extra.out
            }
            else {
                concoct_ch = assembly_ch.join(ont_bam_ch).join(illumina_bam_ch)
                concoct(concoct_ch)
                concoct_out = concoct.out
            }
        }

        // Bin refine

        if (params.skip_metabat2==true) {
            if (  params.skip_maxbin2==true && params.skip_concoct==false) {metawrap_out_ch = norefine(concoct_out).transpose()} // no refine if 1 or less binning method used
            else if ( params.skip_concoct==true && params.skip_maxbin2==false ) {metawrap_out_ch = norefine(maxbin2_out).transpose()}
            else {
                refine2_ch = maxbin2_out.join(concoct_out)
                refine2(refine2_ch, checkm_db_path) // use 2 binning method to refine
                reassembly_ch = refine2.out[0]
                metawrap_out_ch = refine2.out[0].transpose() // the transpose is used to "split" the channel in a channel with each bin file individually
                // e.g without: ch:[ID,[bin1.fa,bin2.fa,bin3.fa]] with : ch:[[ID,bin1.fa],[ID,bin2.fa],[ID,bin3.fa]]
                // this format is needed for further step
            }
        }

        else if (params.skip_maxbin2==true) {
            if (  params.skip_metabat2==true && params.skip_concoct==false) {metawrap_out_ch = norefine(concoct_out).transpose()} // no refine if 1 or less binning method used
            else if ( params.skip_concoct==true && params.skip_metabat2==false ) {metawrap_out_ch = norefine(metabat2_out).transpose()}
            else {
                refine2_ch = metabat2_out.join(concoct_out)
                refine2(refine2_ch, checkm_db_path) // use 2 binning method to refine
                reassembly_ch = refine2.out[0]
                metawrap_out_ch = refine2.out[0].transpose() // the transpose is used to "split" the channel in a channel with each bin file individually
                // e.g without: ch:[ID,[bin1.fa,bin2.fa,bin3.fa]] with : ch:[[ID,bin1.fa],[ID,bin2.fa],[ID,bin3.fa]]
                // this format is needed for further step
            }
        }

        else if (params.skip_concoct==true) {
            if (  params.skip_metabat2==true && params.skip_maxbin2==false) {metawrap_out_ch = norefine(maxbin2_out).transpose()} // no refine if 1 or less binning method used
            else if ( params.skip_maxbin2==true && params.skip_metabat2==false ) {metawrap_out_ch = norefine(metabat2_out).transpose()}
            else {
                refine2_ch = metabat2_out.join(maxbin2_out)
                refine2(refine2_ch, checkm_db_path) // use 2 binning method to refine
                reassembly_ch = refine2.out[0]
                metawrap_out_ch = refine2.out[0].transpose() // the transpose is used to "split" the channel in a channel with each bin file individually
                // e.g without: ch:[ID,[bin1.fa,bin2.fa,bin3.fa]] with : ch:[[ID,bin1.fa],[ID,bin2.fa],[ID,bin3.fa]]
                // this format is needed for further step
            }
        }

        else {
            refine3_ch = metabat2_out.join(maxbin2_out).join(concoct_out)
            refine3(refine3_ch, checkm_db_path)
            reassembly_ch = refine3.out[0]
            metawrap_out_ch = refine3.out[0].transpose() // the transpose is used to "split" the channel in a channel with each bin file individually
                // e.g without: ch:[ID,[bin1.fa,bin2.fa,bin3.fa]] with : ch:[[ID,bin1.fa],[ID,bin2.fa],[ID,bin3.fa]]
                // this format is needed for further step
        }

        //**************
        //Retrieve reads for each bin and assemble them
        //**************
        if (params.reassembly) {
            // retrieve the ids of each bin contigs
            contig_list(reassembly_ch) //retrieve the list of contigs present for each bin
            extract_reads_ch = contig_list.out.view()

        
            // bam align the reads to ALL OF THE CONTIGS 
            cat_all_bins(reassembly_ch) // assemble all bins' contigs in one file for the mapping
            fasta_all_bin = cat_all_bins.out
            bwa_all_bin = fasta_all_bin.join(illumina_input_ch)
            ill_map_all_bin = bwa_bin(bwa_all_bin)    //map illumina reads
            minimap2_all_bin = fasta_all_bin.join(ont_input_ch) 
            ont_map_all_bin = minimap2_bin(minimap2_all_bin) //map ont reads

            // retrieve the reads aligned to the contigs + run unicycler + polish with pilon for 2 round
            retrieve_unmapped_ch = ill_map_all_bin.join( ont_map_all_bin).join(illumina_input_ch).join(ont_input_ch)
            unmapped_retrieve(retrieve_unmapped_ch) //retrieve the reads that didn't map to the contigs to output reads set that can be analysed again
            retrieve_reads_ch = extract_reads_ch.transpose().combine(ill_map_all_bin, by:0).combine( ont_map_all_bin, by:0).combine(illumina_input_ch, by:0).combine(ont_input_ch, by:0)
            reads_retrieval(retrieve_reads_ch).view() //retrieve the reads that mapped to the contigs to allow the reassembly
            unicycler(reads_retrieval.out) // reassemble each bin with the reads mapped to their contigs

            collected_final_bins_ch=unicycler.out[0].collect()
            final_bins_ch=unicycler.out[0]
        }
        else {
            final_bins_ch=metawrap_out_ch
        }
    } //end of step 1
    //*************************************************
    // STEP 2 classify taxa
    //*************************************************
    if (params.modular=="full" | params.modular=="classify" | params.modular=="assem-class" | params.modular=="class-annot") {

        //**************
        // File handling
        //**************

        //bins (list with id (run id not bin) coma path/to/file)
        if (params.bin_classify) { 
            classify_ch = Channel
                .fromPath( params.bin_classify, checkIfExists: true )
                .splitCsv()
                .map { row -> ["${row[0]}", file("${row[1]}", checkIfExists: true)]  }
                .view()
                }

        else {classify_ch=final_bins_ch}
        if (params.modular=="classify" | params.modular=="class-annot") {
            // sourmash_db
            if (params.sourmash_db) { database_sourmash = file(params.sourmash_db) }
            else {
                sourmash_download_db() 
                database_sourmash = sourmash_download_db.out
            }   
            // checkm_db
            if (workflow.profile == 'conda') {
                if (params.checkm_db) {
                    untar = true
                    checkm_setup_db(params.checkm_db, untar)
                    checkm_db_path = checkm_setup_db.out
                }

                else if (params.checkm_tar_db) {
                    untar = false
                    checkm_setup_db(params.checkm_db, untar)
                    checkm_db_path = checkm_setup_db.out
                }
                
                else {
                    untar = false
                    checkm_setup_db(checkm_download_db(), untar)
                    checkm_db_path = checkm_setup_db.out
                }
            }
            else { checkm_db_path = Channel.from("/checkm_database").collectFile() { item -> [ "path.txt", item ]  } }
        }
        //*************************
        // Bins classify workflow
        //*************************

        //checkm of the final assemblies
        checkm(classify_ch.groupTuple(by:0)) //checkm QC of the bins

        //sourmash classification using gtdb database
        sourmash_bins(classify_ch,database_sourmash) // fast classification using sourmash with the gtdb (not the best classification but really fast and good for primarly result)
        sourmash_checkm_parser(checkm.out[0],sourmash_bins.out.collect()) //parsing the result of sourmash and checkm in a single result file

    } // end of step 2
        //*************************************************
        // STEP 3 annotation; kegg pathways + use or RNAseq
        //*************************************************

        if (params.modular=="full" | params.modular=="annotate" | params.modular=="assem-annot" | params.modular=="class-annot") {
            //**************
            // File handling
            //**************
            if (workflow.profile.contains('test')) {
                params.rna = true
            }

            else {
            //RNAseq
                if (params.rna) {rna_input_ch = Channel
                        .fromFilePairs( "${params.rna}/*_R{1,2}.fastq{,.gz}", checkIfExists: true)
                        .view()
                }
            }
            //bins (list with id (run id not bin) coma path/to/file)
            if (params.bin_annotate) {
                bins_input_ch = Channel
                    .fromPath( params.bin_annotate, checkIfExists: true )
                    .splitCsv()
                    .map { row -> ["${row[0]}", file("${row[1]}", checkIfExists: true)]  }
                    .view() 
                    }
            else if (params.bin_classify) {
                bins_input_ch = Channel
                    .fromPath( params.bin_classify, checkIfExists: true )
                    .splitCsv()
                    .map { row -> ["${row[0]}", file("${row[2]}", checkIfExists: true)]  }
                    .view() 
                    }
            else {bins_input_ch = final_bins_ch }

        //************************
        // Databases Dll and setup
        //************************
        if (params.eggnog_db) {eggnog_db=Channel
                .fromPath( params.eggnog_db, checkIfExists: true )}
        else {
            eggnog_download_db()
            eggnog_db = eggnog_download_db.out
            } 
        //*************************
        // Bins annotation workflow
        //*************************

        eggnog_bin_ch= bins_input_ch.combine(eggnog_db)
        eggnog_bin(eggnog_bin_ch) //annotate the bins
        bin_annotated_ch=eggnog_bin.out[0].groupTuple(by:0).view()

        //************************
        // RNA annotation workflow
        //************************
        if (params.rna) {
        // QC
            fastp_rna(rna_input_ch) //qc illumina RNA-seq
            rna_input_ch = fastp_rna.out

        // De novo transcript
            de_novo_transcript_and_quant(rna_input_ch) // de novo transcrip assembly and quantification with trinity and salmon
            transcript_ch=de_novo_transcript_and_quant.out
        // annotations of transcript
            eggnog_rna_ch= transcript_ch.combine(eggnog_db)
            eggnog_rna(eggnog_rna_ch) //annotate the RNA-seq transcripts
            rna_annot_ch=eggnog_rna.out[0].view()
        }

        //******************************************************
        // Parsing bin annot and RNA out into nice graphical out
        //******************************************************

        if (params.rna)  {
            parser_bin_RNA(rna_annot_ch,bin_annotated_ch) // parse the annotations in html summary files
        }
        else {
            parser_bin(bin_annotated_ch) // parse the bins annotation in html summary files
        }
        // Share pathway to put and HTML file with
    } // end of step 3
    
    readme_output()

} // end of workflow{}

workflow.onComplete { 
  log.info ( workflow.success ? "\nDone! Results are stored here --> $params.output \n The Readme file in $params.output describe the structure of the results directories. \n" : "Oops .. something went wrong" )  }
//***********
// MAFIN DONE
//***********
