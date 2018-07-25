#!/bin/bash

last_job_id=""
function slurm {
    filename=$1
    job_name=$2
    mem=$3
    tim=$4
    command=$5
    thread_count=$6
    dependencies=$7
    echo "#!/bin/bash"                                        >  $filename
    echo "#SBATCH --job-name=$job_name"                       >> $filename
    echo "#SBATCH -n $thread_count"                           >> $filename
    echo "#SBATCH --mem $mem"                                 >> $filename
    echo "#SBATCH -t $tim"                                    >> $filename
    echo "#SBATCH --output=$filename.out"                     >> $filename
    echo "#SBATCH --error=$filename.err"                      >> $filename
    echo "#SBATCH --export=all"                               >> $filename
    echo "#SBATCH -p debug,express,normal,big-mem,long"       >> $filename
    if [ $dependencies != "NONE" ]
    then
        echo "#SBATCH --dependency=afterany$dependencies"     >> $filename
    fi
    echo "$command"                                           >> $filename
    # last_job_id=$(sbatch $filename)
}

num_barcodes=5
num_molecules=10
molecule_size_mu=300
random_seed_start=$1
random_seed_step=$2
random_seed_end=$3

calib_deps="NONE"

./benchmark reference reference_name=hg38 gnu_time
make
for random_seed in `seq $random_seed_start $random_seed_step $random_seed_end`
do
    slurm_path=slurm_pbs/random_seed_"$random_seed"
    mkdir -p "$slurm_path"

    barcodes_deps=""
    for barcode_length in {4,8,12};
    do
        job_name="barcodes.bl_$barcode_length.bn_$num_barcodes"
        filename="$slurm_path/$job_name.pbs"
        mem="10240"
        tim="00:59:59"
        command="./benchmark barcodes "
        command=$command"num_barcodes=$num_barcodes "
        command=$command"barcode_length=$barcode_length "
        command=$command"random_seed=$random_seed "
        thread_count=1
        depends="NONE"
        slurm "$filename" "$job_name" "$mem" "$tim" "$command" "$thread_count" "$depends"
        barcodes_deps=$barcodes_deps":"${last_job_id##* }
    done

    molecules_deps=""
    for length_set in 75,HS20 150,HS25 250,MS;
    do
        IFS=",";
        set -- $length_set;
        read_length=$1;
        job_name="molecules.mn_$num_molecules.mu_$molecule_size_mu.rl_$read_length"
        filename="$slurm_path/$job_name.pbs"
        mem="51200"
        tim="02:59:59"
        command="./benchmark molecules "
        command=$command"random_seed=$random_seed "
        command=$command"reference_name=hg38 "
        command=$command"bed=Panel.hg38 "
        command=$command"num_molecules=$num_molecules "
        command=$command"molecule_size_mu=$molecule_size_mu "
        command=$command"read_length=$read_length "
        thread_count=1
        depends="$barcodes_deps"
        slurm "$filename" "$job_name" "$mem" "$tim" "$command" "$thread_count" "$depends"
        molecules_deps=$molecules_deps":"${last_job_id##* }
    done
    simulate_deps=""

    for barcode_length in {4,8,12};
    do
        for length_set in 75,HS20 150,HS25 250,MS;
        do
            IFS=",";
            set -- $length_set;
            read_length=$1;
            sequencing_machine=$2;
            job_name="simulate.bl_$barcode_length.rl_$read_length"
            filename="$slurm_path/$job_name.pbs"
            mem="51200"
            tim="05:59:59"
            command="./benchmark simulate make_calib_log_file "
            command=$command"random_seed=$random_seed "
            command=$command"reference_name=hg38 "
            command=$command"bed=Panel.hg38 "
            command=$command"num_molecules=$num_molecules "
            command=$command"num_barcodes=$num_barcodes "
            command=$command"barcode_length=$barcode_length "
            command=$command"molecule_size_mu=$molecule_size_mu "
            command=$command"read_length=$read_length "
            command=$command"sequencing_machine=$sequencing_machine "
            thread_count=1
            depends="$barcodes_deps""$molecules_deps"
            slurm "$filename" "$job_name" "$mem" "$tim" "$command" "$thread_count" "$depends"
            simulate_deps=$simulate_deps":"${last_job_id##* }
        done
    done

    for barcode_length in {4,8,12};
    do
        for length_set in 75,HS20 150,HS25 250,MS;
        do
            IFS=",";
            set -- $length_set;
            read_length=$1;
            sequencing_machine=$2;
            # calib_log
            for error_tolerance in 1 2
            do
                for kmer_size in 4 8
                do
                    for param_set in 3,1 3,2 4,1 4,2 4,3 5,2 5,3 5,4 6,2 6,3 6,4 6,5 7,2 7,3 7,4 7,5 7,6;
                    do
                        IFS=",";
                        set -- $param_set;
                        minimizers_num=$1;
                        minimizers_threshold=$2;
                        job_name="calib.bl_$barcode_length.rl_$read_length.e_$error_tolerance.k_$kmer_size.m_$minimizers_num.t_$minimizers_threshold"
                        filename="$slurm_path/$job_name.pbs"
                        mem="51200"
                        tim="02:59:59"
                        thread_count=8
                        command="./benchmark calib_log "
                        command=$command"random_seed=$random_seed "
                        command=$command"reference_name=hg38 "
                        command=$command"bed=Panel.hg38 "
                        command=$command"num_molecules=$num_molecules "
                        command=$command"num_barcodes=$num_barcodes "
                        command=$command"barcode_length=$barcode_length "
                        command=$command"molecule_size_mu=$molecule_size_mu "
                        command=$command"read_length=$read_length "
                        command=$command"sequencing_machine=$sequencing_machine "
                        command=$command"barcode_error_tolerance=$error_tolerance "
                        command=$command"kmer_size=$kmer_size "
                        command=$command"minimizers_num=$minimizers_num "
                        command=$command"minimizers_threshold=$minimizers_threshold "
                        command=$command"thread_count=$thread_count "
                        depends="$simulate_deps"
                        slurm "$filename" "$job_name" "$mem" "$tim" "$command" "$thread_count" "$depends"
                        calib_deps=$calib_deps":"${last_job_id##* }
                    done
                done
            done
        done
    done
done

command=""
for barcode_length in {4,8,12};
do
    for length_set in 75,HS20 150,HS25 250,MS;
    do
        IFS=",";
        set -- $length_set;
        read_length=$1;
        sequencing_machine=$2;
        filename="bl_$barcode_length.rl_$read_length.tsv"
        for random_seed in `seq $random_seed_start $random_seed_step $random_seed_end`
        do
            tsv_path="simulating/datasets"
            tsv_path=$tsv_path"/randS_"$random_seed
            tsv_path=$tsv_path"/barL_"$barcode_length
            tsv_path=$tsv_path".barNum_"$num_barcodes
            tsv_path=$tsv_path"/ref_hg38.bed_Panel.hg38.molMin_"$read_length
            tsv_path=$tsv_path".molMu_"$molecule_size_mu
            tsv_path=$tsv_path".molDev_25"
            tsv_path=$tsv_path".molNum"$num_molecules
            tsv_path=$tsv_path"/pcrC_7.pcrDR_0.6.pcrER_0.00005/seqMach_"$sequencing_machine
            tsv_path=$tsv_path".readL_"$read_length
            tsv_path=$tsv_path"/calib_benchmarks.tsv"

            command=$command"if [ ! -f $filename ]; then head -n1 $tsv_path > $filename; fi; awk 'NR > 1' $tsv_path >> $filename; "
        done
    done
done

job_name="group_"$random_seed_start"_"$random_seed_step"_"$random_seed_end""
filename="slurm_pbs/$job_name.pbs"
mem="128"
tim="00:04:59"
thread_count=1
depends="$calib_deps"
slurm "$filename" "$job_name" "$mem" "$tim" "$command" "$thread_count" "$depends"


exit