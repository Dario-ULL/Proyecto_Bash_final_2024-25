#!/bin/bash

# Default sorting criterion
orden_por_defecto="user"  # Use "user" for sorting

# Option variables
incluir_sid_cero=false  # Indicates whether to include processes with SID 0
usuario_especificado=()  # Array for usernames specified with -u
directorio=""            # Directory specified with -d
limitar_numero_procesos=false
solo_terminal=false       # Variable para comprobar si se ha especificado -t
tabla_sesiones=false      # Variable para comprobar si se ha especificado -e
# Function to display help
mostrar_ayuda() {
    echo "Usage: infosession.sh [-h] [-z] [-u usuario] [-d directorio]"
    echo
    echo "Options:"
    echo "  -h        Show this help and exit."
    echo "  -z        Include processes with session ID 0."
    echo "  -u user   Show processes for the specified user."
    echo "  -d dir    Show only processes with open files in the specified directory."
    echo "  -w        Show only the first 5 processes."
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
        mostrar_error "$cmd is not available. Please install it and try again." "5"
    fi
done

# Función para mostrar información de procesos
mostrar_procesos_usuario() {
    local orden="$1"                  
    local usuarios=("${!2}")          
    local dir="$3"                     
    local limitar_numero="$4"  
    local limiar_terminal="$5"     
    local salida_procesos             

    for usuario in "${usuarios[@]}"; do
        if ! id -u "$usuario" &>/dev/null; then
            mostrar_error "User '$usuario' does not exist." "6"
        fi
    done

    if [[ ${#usuarios[@]} -eq 0 ]]; then
        usuarios=($(whoami)) 
    fi
    printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n" "SID" "PGID" "PID" "USER" "TTY" "%MEM" "CMD"
    for usuario in "${usuarios[@]}"; do
        if [[ -n "$dir" ]]; then
            # Obtener los PIDs de los procesos que tienen archivos abiertos en el directorio
            pids=$(lsof +D "$dir" | awk 'NR > 1 {print $2}' | sort -u)
            salida_procesos=$(ps -eo sid,pgid,pid,user,tty,%mem,cmd --sort="${orden}" | awk -v user="$usuario" -v incluir_sid_cero="$incluir_sid_cero" -v limit="$limitar_numero" -v count="$count" -v limiar_terminal="$limiar_terminal" -v pids="$pids" '
            BEGIN { split(pids, pid_array, " ") }
            {
                if ($4 == user && ((incluir_sid_cero == "true") || ($1 != "0"))) {
                    if (limiar_terminal == "true" && $5 == "?") next
                    for (pid in pid_array) {
                        if ($3 == pid_array[pid]) {
                            printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n", $1, $2, $3, $4, $5, $6, $7
                            if (limit == "true" && ++count > 5) exit
                        }
                    }
                }
            }')
        else
            salida_procesos=$(ps -eo sid,pgid,pid,user,tty,%mem,cmd --sort="${orden}" | awk -v user="$usuario" -v incluir_sid_cero="$incluir_sid_cero" -v limit="$limitar_numero" -v count="$count" -v limiar_terminal="$limiar_terminal" '
            {
                if ($4 == user && ((incluir_sid_cero == "true") || ($1 != "0"))) {
                    if (limiar_terminal == "true" && $5 == "?") next
                    printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n", $1, $2, $3, $4, $5, $6, $7
                    if (limit == "true" && ++count > 5) exit
                }
            }')
        fi
        echo "$salida_procesos"
        if [[ "$limitar_numero_procesos" == true && $(echo "$salida_procesos" | wc -l) -lt 5 ]]; then
            echo "Advertencia: No se encontraron 5 procesos para mostrar."
        fi
    done
}

# Procesar opciones
while getopts ":hzwteu:d:" opcion; do
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
            tabla_sesiones
            ;;
        u)
            if [[ -z "$OPTARG" ]]; then
                mostrar_error "Option -u requires at least one username." "1"
            fi
            usuario_especificado+=("$OPTARG")
            while [[ ${!OPTIND} && ${!OPTIND} != -* ]]; do
                usuario_especificado+=("${!OPTIND}")
                OPTIND=$((OPTIND + 1))
            done
            ;;
        d)
            if [[ -z "$OPTARG" ]]; then
                mostrar_error "Option -d requires a directory." "2"
            fi
            directorio="$OPTARG"
            ;;
        \?)
            mostrar_error "Invalid option: -$OPTARG" "3"
            ;;
        :)
            mostrar_error "Option -$OPTARG requires an argument." "4"
            ;;
    esac
done

# Mostrar la tabla de procesos con los parámetros establecidos
mostrar_procesos_usuario "$orden_por_defecto" usuario_especificado[@] "$directorio" "$limitar_numero_procesos" "$solo_terminal"