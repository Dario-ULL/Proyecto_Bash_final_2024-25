#!/bin/bash

# Option variables
incluir_sid_cero=false          # Indicates whether to include processes with SID 0
usuario_especificado=()         # Array for usernames specified with -u
directorio=""                   # Directory specified with -d
limitar_numero_procesos=false   # Variable para comprobar si se ha especificado -w
solo_terminal=false             # Variable para comprobar si se ha especificado -t
tabla_sesiones=true             # Variable para comprobar si se ha especificado -e
ordenar_por_memoria=false       # Variable para comprobar si se ha especificado -sm
ordenar_numero_grupos=false     # Variable para comprobar si se ha especificado -sg
invertir_orden=false            # Variable para comprobar si se ha especificado -r
# Function to display help
mostrar_ayuda() {
    echo "Uso: infosession.sh [-h] [-e ] [-z] [-u user1 ... ] [ -d dir ] [-t ] [-sm] [-r]"
    echo "Uso: infosession.sh [-h] [-z] [-u user1 ... ] [ -d dir ] [-t ] [-sg/sm] [-r]"
    echo
    echo "Opciones:"
    echo "  -h          Muestra esta ayuda y sale."
    echo "  -z          Incluye los procesos con ID de sesión 0."
    echo "  -u usuario  Muestra los procesos para el usuario especificado."
    echo "  -d dir      Muestra solo los procesos con archivos abiertos en el directorio especificado."
    echo "  -w          Muestra solo los primeros 5 procesos."
    echo "  -t          Muestra solo los procesos con terminal."
    echo "  -e          Muestra una tabla de sesiones."
    echo "  -sm         Ordena por uso de memoria."
    echo "  -sg         Ordena por número de grupos de procesos."
    echo "  -r          Invierte el orden de la ordenación."
    exit 0
}

# Function to display errors
mostrar_error() {
    echo "Error: $1" >&2
    exit "$2"
}

# Check availability of external tools
for cmd in ps awk id lsof; do
    if ! command -v $cmd &> /dev/null; then
        mostrar_error "$cmd no es accecible. Pruebe a instalarlo y vuelva a intentarlo." "5"
    fi
done

mostrar_procesos_usuario() {
    local usuarios=("${!1}")            # Lista de usuarios
    local dir="$2"                      # Directorio (opcional)
    local limitar_numero="$3"           # Limitar número de procesos
    local limitar_terminal="$4"         # Limitar a procesos con terminal
    local ordenar_por_memoria="$5"      # Ordenar por memoria
    local invertir_orden="$6"           # Invertir el orden
    local salida_procesos               # Variable para almacenar la salida de ps
    local salida_resumen                # Variable para almacenar la tabla de resumen
    local procesos_por_sesion=()        # Array para almacenar el número de grupos por sesión
  
    # Comprobar existencia de usuarios
    for usuario in "${usuarios[@]}"; do
        if ! id -u "$usuario" &>/dev/null; then
            mostrar_error "El usuario: '$usuario' no existe." "6"
        fi
    done

    # Si no se especifican usuarios, se usa el usuario actual
    if [[ ${#usuarios[@]} -eq 0 ]]; then
        usuarios=($(whoami))
    fi
    
    # Encabezado de la tabla
    printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n" "SID" "PGID" "PID" "USER" "TTY" "%MEM" "CMD"

    for usuario in "${usuarios[@]}"; do
        if [[ -n "$dir" ]]; then
            pids=$(lsof +D "$dir" | awk 'NR > 1 {print $2}' | sort -u)
            salida_procesos=$(ps -eo sid,pgid,pid,user,tty,%mem,cmd | awk -v user="$usuario" -v incluir_sid_cero="$incluir_sid_cero" -v limit="$limitar_numero" -v count="$count" -v limitar_terminal="$limitar_terminal" -v pids="$pids" '
            BEGIN { split(pids, pid_array, " ") }
            {
                if ($4 == user && ((incluir_sid_cero == "true") || ($1 != "0"))) {
                    if (limitar_terminal == "true" && $5 == "?") next
                    for (pid in pid_array) {
                        if ($3 == pid_array[pid]) {
                            printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n", $1, $2, $3, $4, $5, $6, $7
                        }
                    }
                }
            }')
        else
            salida_procesos=$(ps -eo sid,pgid,pid,user,tty,%mem,cmd | awk -v user="$usuario" -v incluir_sid_cero="$incluir_sid_cero" -v limit="$limitar_numero" -v count="$count" -v limitar_terminal="$limitar_terminal" '
            {
                if ($4 == user && ((incluir_sid_cero == "true") || ($1 != "0"))) {
                    if (limitar_terminal == "true" && $5 == "?") next
                    printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n", $1, $2, $3, $4, $5, $6, $7
                }
            }')
        fi

        if [[ "$ordenar_por_memoria" == true ]]; then
            salida_procesos=$(echo "$salida_procesos" | sort -k6 -n) 
        fi

        if [[ "$ordenar_por_memoria" == true ]]; then
            if [[ "$invertir_orden" == true ]]; then
                salida_procesos=$(echo "$salida_procesos" | sort -k6 -n -r)
            else 
                salida_procesos=$(echo "$salida_procesos" | sort -k6 -n) 
            fi
        fi

        echo "$salida_procesos"
    done
}

mostrar_tabla_sesiones() {
    local incluir_sid_cero=$1       # Incluir SID 0
    local usuarios=("${!2}")        # Lista de usuarios
    local directorio=$3             # Directorio
    local solo_terminal=$4          # Mostrar solo procesos con terminal
    local ordenar_por_memoria=$5    # Ordenar por memoria
    local ordenar_por_grupos=$6     # Ordenar por número de grupos de procesos
    local invertir_orden=$7         # Añadimos la opción para invertir el orden

    if [[ "$ordenar_por_grupos" == true && "$ordenar_por_memoria" == true ]]; then
        mostrar_error "Opción -sg no es compatible con la opcion -sm" "8"
    fi
    
    # Obtener y filtrar la lista de procesos
    process_list=$(ps -eo pid,sid,pgid,pcpu,pmem,user,tty,comm --sort=sid,pgid)

    # Filtrar según opciones -z, -u, -d y -t
    if [[ "$incluir_sid_cero" == false ]]; then
        process_list=$(echo "$process_list" | awk '$2 != 0')
    fi

    if [[ "${#usuarios[@]}" -gt 0 ]]; then
        process_list=$(echo "$process_list" | awk -v users="${usuarios[*]}" 'BEGIN {split(users, u); for (i in u) user_map[u[i]]} $6 in user_map')
    fi

    if [[ -n "$directorio" ]]; then
        pids=$(lsof +D "$directorio" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
        process_list=$(echo "$process_list" | awk -v pids="$pids" 'BEGIN {split(pids, a); for (i in a) pid_map[a[i]]} $1 in pid_map')
    fi

    if [[ "$solo_terminal" == true ]]; then
        process_list=$(echo "$process_list" | awk '$7 != "?" && $7 != ""')
    fi

    # Encabezado de la tabla
    printf "%-10s %-15s %-15s %-15s %-15s %-10s %-15s\n" \ "SID" "Total Grupos" "Total %MEM" "PID Líder" " Usuario Líder" "  TTY" "  Comando"

    # Procesar la lista de procesos para generar la tabla de sesiones
    session_data=()
    for session in $(echo "$process_list" | awk '{print $2}' | sort -u); do
        [[ -z "$session" || "$session" == "SID" ]] && continue

        total_groups=$(echo "$process_list" | awk -v sid="$session" '$2 == sid {print $3}' | sort -u | wc -l)
        total_memory=$(echo "$process_list" | awk -v sid="$session" '$2 == sid {sum += $5} END {print sum}')

        leader_pid=$session
        leader_info=$(echo "$process_list" | awk -v pid="$leader_pid" '$1 == pid')

        if [ -n "$leader_info" ]; then
            leader_user=$(echo "$leader_info" | awk '{print $6}')
            leader_terminal=$(echo "$leader_info" | awk '{print $7}')
            leader_command=$(echo "$leader_info" | awk '{print $8}')
        else
            leader_user="?"
            leader_terminal="?"
            leader_command="?"
        fi

        # Agregar datos de la sesión al arreglo
        session_data+=("$(printf "%-10s %-15s %-15s %-15s %-15s %-10s %-15s" \ "$session" "$total_groups" "$total_memory" "$leader_pid" "$leader_user" "$leader_terminal" "$leader_command")")
    done



    if [[ "$ordenar_por_grupos" == true ]]; then
        if [[ "$invertir_orden" == true ]]; then 
            printf "%s\n" "${session_data[@]}" | sort -k2 -n -r
        else 
            printf "%s\n" "${session_data[@]}" | sort -k2 -n
        fi
    elif [[ "$ordenar_por_memoria" == true ]]; then
        # Si -r está activado, invertir el orden
        if [[ "$invertir_orden" == true ]]; then
            printf "%s\n" "${session_data[@]}" | sort -k3 -n -r
        else
            printf "%s\n" "${session_data[@]}" | sort -k3 -n
        fi
    else
        # Si -r está activado, invertir el orden por SID
        if [[ "$invertir_orden" == true ]]; then
            printf "%s\n" "${session_data[@]}" | sort -k1 -n -r
        else
            printf "%s\n" "${session_data[@]}" | sort -k1 -n
        fi
    fi
}



# Procesar opciones
while getopts ":hzwters:u:d:" opcion; do
    case $opcion in
        h)
            mostrar_ayuda
            ;;
        z)
            incluir_sid_cero=true 
            ;;
        w) 
            limitar_numero_procesos=true
            ;;
        t) 
            solo_terminal=true
            ;;
        e)
            tabla_sesiones=false
            ;;
        r)
            invertir_orden=true 
            ;;
        u)
            if [[ -z "$OPTARG" ]]; then
                mostrar_error "La opcion -u requiere de al menos un nombre de usuario." "1"
            fi
            usuario_especificado+=("$OPTARG")
            while [[ ${!OPTIND} && ${!OPTIND} != -* ]]; do
                usuario_especificado+=("${!OPTIND}")
                OPTIND=$((OPTIND + 1))
            done
            ;;
        d)
            if [[ -z "$OPTARG" ]]; then
                mostrar_error "La opcion -d requiere de una direccion." "2"
            fi
            directorio="$OPTARG"
            ;;
        s)
            # Verificar si la opción -s está seguida por m o g
            if [[ "$OPTARG" == "m" ]]; then
                ordenar_por_memoria=true
            elif [[ "$OPTARG" == "g" ]]; then
                ordenar_numero_grupos=true
            else
                mostrar_error "Opción -s con argumento inválido" "9"
            fi
            ;;

        \?)
            mostrar_error "Opcion invalida: -$OPTARG" "3"
            ;;
        :)
            mostrar_error "La opcion -$OPTARG requiere algun argumento." "4"
            ;;
    esac
done

# Show the session table if -e is set
if [[ "$tabla_sesiones" == true ]]; then
    mostrar_tabla_sesiones "$incluir_sid_cero" usuario_especificado[@] "$directorio" "$solo_terminal" "$ordenar_por_memoria" "$ordenar_numero_grupos" "$invertir_orden"
else
    if [[ "$ordenar_numero_grupos" == true ]]; then
        mostrar_error "Opción -sg no es compatible con la tabla de procesos de usuario" "7"
    fi
    mostrar_procesos_usuario usuario_especificado[@] "$directorio" "$limitar_numero_procesos" "$solo_terminal" "$ordenar_por_memoria" "$invertir_orden"
fi