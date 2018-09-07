workflow validation_pipeline {
	File truth_vcf
	File query_vcf
 	File bedfile
	File reference_fasta
	File reference_fasta_index
	String prefix
	String results_folder

	call vcf_evaluation {
		input:
			truth_vcf = truth_vcf,
			query_vcf = query_vcf,
			bedfile = bedfile,
			prefix = prefix,
			reference_fasta_index = reference_fasta_index,
			reference_fasta = reference_fasta
	}

	call copy {
		input:
			files = [
				vcf_evaluation.stratified_summary,
				vcf_evaluation.metrics,
				vcf_evaluation.roc_snp_pass,
				vcf_evaluation.roc_snp,
				vcf_evaluation.roc_all,
				vcf_evaluation.roc,
				vcf_evaluation.runinfo,
				vcf_evaluation.summary,
				vcf_evaluation.vcf,
				vcf_evaluation.vcf_indexed
				],
			destination = results_folder
	}
}

task vcf_evaluation {

	File truth_vcf
	File query_vcf
	File bedfile
	File reference_fasta
	File reference_fasta_index
	String prefix

	command {
		/opt/hap.py/bin/hap.py ${truth_vcf} ${query_vcf} \
		-f ${bedfile} -o ${prefix} -r ${reference_fasta} \
		--verbose --gender "none" --preprocess-truth \
		--write-vcf
		}


	runtime {
		docker: "pkrusche/hap.py"
	}

	output {
		File stratified_summary = prefix + ".extended.csv"
		File metrics = prefix + ".metrics.json.gz"
		File roc_snp_pass = prefix + ".roc.Locations.SNP.PASS.csv.gz"
		File roc_snp = prefix + ".roc.Locations.SNP.csv.gz"
		File roc_all = prefix + ".roc.all.csv.gz"
		File roc = prefix + ".roc.tsv"
		File runinfo = prefix + ".runinfo.json"
		File summary = prefix + ".summary.csv"
		File vcf = prefix + ".vcf.gz"
		File vcf_indexed = prefix + ".vcf.gz.tbi"
	}
}

task copy {
	Array[File] files
	String destination

	command {
		mkdir -p ${destination}
		cp -L -R -u ${sep=' ' files} ${destination}
	}

	output {
		Array[File] out = files
	}
}
