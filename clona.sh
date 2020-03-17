#!/bin/bash

# Author: Otávio Vargas
# Created Date: 18/01/2017
# http://www.otaviovargas.com
# Script of https://github.com/lamw/ghettoVCB

##################################################################
#                   Definindo Parâmetros
##################################################################
#Lista de Hypervisions
hypervision=(
	"Digie o IP do Hypervision"
)
#Inicializando a data no formato do Brasil
data=`date +%d-%m-%Y`

#Inicializando as variáveis globais
#Return da funçao: escolheStorage
RETURNescolheStorage=""
#Pasta onde será colocado os logs
pastaLog="log"

##################################################################
#                       Funções
##################################################################
#Verifica se o script já foi instalado, caso não, instala
instalar(){
	arq="/usr/bin/clona"
	if  [[ ! -h "$arq" ]]
		then
		localScript=`pwd`
		`ln -s $localScript/clona.sh /usr/bin/clona`
		ssh-keygen
		if [[ ! -e $pastaLog ]]; then
    		mkdir $pastaLog
		fi
		echo "Instalação Concluida!"
	fi
}
#As primeiras linhas do arquivo de log
cabecarioDoLog(){
	echo "###############################################################################" >> $execEm/log/log-$data.txt
    echo "#"
    echo "#                                 Clona 6.5 $hora | $data" >> log/log-$data.txt
    echo "#"
    echo "###############################################################################" >> $execEm/log/log-$data.txt
}
# Atualiza os certificados dos Hypervisions para um só, para comunicar sem senha.
# É necessário que já tenha criado o certificado ssl
atualizarTodosCertificados() {
	for hyper in "${hypervision[@]}"
		do
		echo "Atualizando certificado do hypervision: $hyper" >> $execEm/log/log-$data.txt
		ssh $hyper "mkdir -p /etc/ssh/keys-root/" >> $execEm/log/log-$data.txt
    	scp /root/.ssh/id_rsa* $hyper:/etc/ssh/keys-root/ >> $execEm/log/log-$data.txt
		ssh $hyper "cat /etc/ssh/keys-root/id_rsa.pub >> /etc/ssh/keys-root/authorized_keys" >> $execEm/log/log-$data.txt
	done
}
# Lista para o usuário os storages disponíves do hypervision escolhido anteriormente, para fazer o backup
escolherStorage(){
	clear
		j=0
		opcao=0
		h=$1
		stg=(`ssh $h "ls -la /vmfs/volumes/" | grep "\->" | awk '{print $9}'`)
		echo "Escolha o Storage:"
		for lstg in "${stg[@]}"
			do 
			echo "$j- $lstg"
			j=$((j+1))
		done
		echo
		printf 'Opcao:'
        read -r opcao
		RETURNescolheStorage=${stg[opcao]}
}	
# Comando que envia e executa o script gettoVCB.sh
executar () {
	#Zerar a variável, caso nao haja máquina virtual específica
	execm=""
	# Hypervision desejado    		
	exech=$1
	# Caminho do storage
    execs=$2
	#Opcao (-a para todas as vms ou -m para uma vm específica)
	execm=$3
	#local onde será realizado o backup
	echo "/vmfs/volumes/$execs/BACKUP/" > $execEm/ghettoVCB-master/destino
	# Acessa o Hypervision e remove a pasta antiga do script, se houver
	ssh $exech "rm -rf /sbin/ghettoVCB-master"
	# Remove possíveis resíduos de backups anteriores
	ssh $exech "rm -rf /tmp/ghettoVCB.work"
	# Copia os arquivos do servidor de backup para o Hypervision desejado
	scp -r $execEm/ghettoVCB-master $exech:/sbin/ 
	# Dá permissão para que o script possa ser executado	
	ssh $exech "chmod +x /sbin/ghettoVCB-master/ghettoVCB.sh"
	# Executa de fato o script, passando os parametros recebidos para o gettoVCB.sh
	# Lembrando que existe 1 alteração no script gettoVCB.sh para receber o caminho do storage
	ssh $exech "nohup /sbin/ghettoVCB-master/ghettoVCB.sh $execm"
}
#Menu Principal
menuPrincipal() {
		clear
        echo "###############################################################################"
        echo "#"
        echo "#                                 Clona 6.5"
        echo "#                        ESX/ESXi 3.5, 4.x+, 5.x & 6.x"
 		echo "#"	
        echo "# Author: Otávio Vargas, baseado no script de William Lam"
        echo "# http://www.otaviovargas.com    | http://www.virtuallyghetto.com/"
        echo "# Documentação: Documentação.txt | http://communities.vmware.com/docs/DOC-8760"
        echo "# Criado: 18/01/2017"
        echo "#"
        echo "###############################################################################"
        echo
        echo "Menu:"
        echo "   1     Backup de apenas uma maquina virutal"
        echo "   2     Backup de todas as maquinas virtuais de um Hypervision"
        echo "   3     Sair"
        echo
		printf 'Opcao:'
        read -r opcao
        case $opcao in
		   1) menu1;;
		   2) menu2;;
		   3) ;;
        esac

}
# Menu 1: Para escolher a máquina virutal para fazer o backup
menu1() {
		clear
		echo "Maquinas Virtuais:"
		i=0
		opcao=-1
		for hyper in "${hypervision[@]}"
			do
			echo "[$hyper]"
			vms=(`ssh $hyper "vim-cmd vmsvc/getallvms" | sed '1d' | awk '{print $2}'`)
			for vmlist in "${vms[@]}"
				do 
				vmlista[i]=$vmlist 
				h1[i]=$hyper
				echo "$i- $vmlist"
				i=$((i+1))
			done
			echo
		done
		printf 'Opcao:'
        read -r opcao1
		escolherStorage ${h1[$opcao1]}
		executar ${h1[$opcao1]} $RETURNescolheStorage "-m ${vmlista[$opcao1]}"				
}
# Menu 2: Seleciona o hypervision para realizar o backup
menu2() {
	count=0
	echo "Hypervisions:"
	for hyper in "${hypervision[@]}"
		do
	    echo "   $count- $hyper "
		count=$((count+1))
	done
	printf 'Opcao:'
    read -r opcao2
	escolherStorage ${hypervision[opcao2]}
    executar ${hypervision[opcao2]} $RETURNescolheStorage "-a"
	
}

##################################################################
#                           Main
##################################################################
instalar
execEm="$(dirname "$(realpath /usr/bin/clona)")"
cabecarioDoLog
clear
echo "Atualizando os certificado dos hypervisions..."
atualizarTodosCertificados
clear
menuPrincipal
