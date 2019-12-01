#!/bin/bash
#a = arquivo
#q = quantidade de máquinas
#c = se a máquina atual é cliente
#ip = ip do servidor

SouC=
qnt=0
arq=
ip=
arqTemp=

if [ $# -eq 0 ] ; then printf "Servidor\n$0 -a <arquivo> -q <Quantidade de Máquinas>\n\nCliente\n$0 -c <Ip do Servidor>\n" ; exit ; fi

while getopts "a:q:c:" OPTVAR
do
	if [ "$OPTVAR" = "a" -a $OPTARG ] ; then
		arq=$OPTARG
	elif [ "$OPTVAR" = "q" -a $OPTARG ] ; then
		qnt=$OPTARG
	elif [ "$OPTVAR" = "c" ] ; then
		SouC="c"
		ip=$OPTARG
	else
		echo "Servidor"
		echo "$0 -a <arquivo> -q <Quantidade de Máquinas>"
		echo ""
		echo "Cliente"
		echo "$0 -c <Ip do Servidor>"
		exit
	fi
done 2> /dev/null

if [ \( ! "$SouC" \) -a \( "$qnt" -le "1" \) ] ; then
	arqTemp=$arq
else
	arqTemp="./temp.txt"
fi

if [ \( ! "$SouC" \) -a \( "$qnt" -gt "1" \) ] ; then
	linha=`cat $arq | wc -l`
	taill=$(($linha / $qnt))
	headd=$taill
	md=$(($linha % $qnt))

	#echo "$(ifconfig -a | grep broadcast | sed 's/netmask.*//g; s/[^0-9.]//g')"

	hostname -I

	for i in `seq $(($qnt - 1))` ; do
		echo "Enviando uma parte do texto para máquina: $i"
		enviado=$(nc -l -p 7000 -w 2 < <(head -$headd $arq | tail -$taill))
		printf "$enviado\n"
		headd=$(($headd + $taill))
	done
	cat $arq | tail -$(($taill + $md)) > ./temp.txt
elif [ $SouC ] ; then
	echo "Recebendo minha parte do texto..."
	while [ 1 ] ; do
		if [ $(nc $ip 7000 < <(printf "\nEnviado\n") | tee ./temp.txt | wc -l) -ne 0 ] ; then
			break
		fi
		sleep 1
	done
fi

#estimativa

ini=`date +%s`

pala=$(awk '{
		for(i=1;i<=NF;i++){
	        	quanto++
			if(quanto == 2000000){
				exit
			}
		}
}
END {
	print quanto
}' $arqTemp)

fim=`date +%s`

totalP=`wc -w $arqTemp | cut -f1 -d' '`
tempo=$(($fim - $ini))

if [ $tempo -eq 0 ] ; then
	tempo=1
fi

if [ \( ! "$SouC" \) -a \( "$qnt" -gt "1" \) ] ; then
	for i in `seq $(($qnt - 1))` ; do
		mensRec=$(nc -l -p 7002 -w 2 < <(printf "Ok\n"))
		tempoC=$(printf "$mensRec\n" | head -1)
		totalPC=$(printf "$mensRec\n" | head -2 | tail -1)
		palaC=$(printf "$mensRec\n" | head -3 | tail -1)
		estimadoC=$(printf "$mensRec\n" | tail -1)
		echo -e "Tempo estimado da máquina $i: $estimadoC s\n"
		tempo=$(($tempo + $tempoC))
		pala=$(($pala + $palaC))
		totalP=$(($totalP + $totalPC))
	done
	estimado=$((($totalP  * $tempo) / $pala))
	echo "Tempo estimado de todas as máquinas"	
	echo "$pala Palavras a cada $tempo s"
	echo "Tempo estimado em segundo: $estimado"
	echo -e "Tempo estimado: `date --date="@$(($estimado + 10800))" +%T`\n"
elif [ $SouC ] ; then
	estimadoCliente=$((($totalP  * $tempo) / $pala))

	echo -e "Enviando tempo estimado...\n"
	while [ 1 ] ; do
		if [ $(nc $ip 7002 < <(printf "$tempo\n$totalP\n$pala\n$estimadoCliente\n")) ] ; then
			break
		fi
		sleep 1
	done

	echo "$pala Palavras a cada $tempo s"
	echo "Tempo estimado em segundos: $estimadoCliente s"
	echo -e "Tempo estimado: `date --date="@$(($estimadoCliente + 10800))" +%T`\n"
fi

declare -A vet

tempo1=`date +%s`

sed 's/[[:punct:]]//g' $arqTemp | awk '{
	for(i=1;i<=NF;i++){
	temp = $i
  	registro[temp]=registro[temp] + 1
      	quanto++
	}
}
END {
	for (x in registro){
		printf "%s: %s\n" ,x ,registro[x]
	}
	printf "Total de Palavras analisadas: %s\n" ,quanto
}' > ./palavras.txt

tempo2=`date +%s`

#for i in `cat ./temp.txt`
#do
#	temp=$(echo $i | sed "s/[[:punct:]]//g")
#	if [ $temp ]
#       	then
#		#clear
#		#palavras=$(($palavras + 1 ))
#		#echo "Total de Palavras = $total. Palavras Analisadas = $palavras"
#		if [ ${vet[$temp]} ] ; then
#			vet[$temp]=$((${vet[$temp]} + 1))
#		else
#			vet[$temp]=1
#		fi
#	fi
#done

tempo=$(($tempo2 - $tempo1))

#for i in ${!vet[@]} ; do
#	echo "$i ${vet[$i]}"
#done

if [ ! $SouC ] ; then
	for i in `seq $(($qnt - 1))` ; do
		tempoMaq=$(nc -l -p 7003 -w 1 < <(printf "Ok\n"))
		echo "Tempo de contagem da máquina $i: $tempoMaq s"
		tempo=$(($tempo + $tempoMaq))
		
	done
else
	while [ 1 ] ; do
		if [ $(nc $ip 7003 < <(printf "$tempo\n")) ] ; then
			break	
		fi
		sleep 1
	done
fi

echo "$(date --date="@$(($tempo + 10800))" +%T)" | tee -a ./resultado.txt

rm -f ./temp.txt
