	ORG 0				;Dirección de inicio del programa
	SJMP RUTINA_INICIALIZACION	;Salto a la subrutina de inicialización


	ORG 000BH			;Establece la subrutina de atención a la interrupción de la interrupción provocada por el exceso del timer 0
ACELERAR:				;Subrutina que acelera un 10% de la capacidad del PWM
	SUBB A,#15H			;Resta este valor al acumulador para asegurar que llegue a la máxima capacidad del PWM
	JZ MAXIMO			;Si el valor del acumulador es 0, salta a la subrutina final
	ADD A,#15H			;Si no se le vuelve a añadir el valor
	SUBB A,#1AH			;Se le añade un 10% de la capacidad del PWM al acumulador
	MOV 0FCH,A			;Se mueve al registro del PWM0 el valor del acumulador
	SJMP ACELERANDO			;Acaba la subrutina de atención a la interrupción y vuelve al estado acelerando
MAXIMO:					;Subrutina que establece la máxima capacidad al PWM0
	MOV 0FCH,A			;Mueve al registro del PWM0 el valor del acumulador
	SJMP ACELERANDO			;Acaba la subrutina de atención a la interrupción y vuelve al estado acelerando


RUTINA_INICIALIZACION:			;Subrutina de inicialización
INIT_FLAGS:				;Subrutina que pone a cero los flags utilizados para indicar la activación de un evento
	CLR 20H				;Ponemos a cero el flag que indica si ha habido algún error en la apertura o el cierre de la puerta
	CLR 21H				;Ponemos a cero el flag que indica si hay sobrepeso
INIT_DISPLAYS:				;Subrutina que inicializa los displays
	ACALL ACTUALIZAR_DISPLAYS	;Llama a la subrutina que actualiza los displays
INIT_ASCENSOR:				;Subrutina que inicializa las características del ascensor
	MOV 0FCH,#0FFH			;Pone a nivel bajo el PWM0 (ascensor parado)
INIT_EST:				;Subrutina que establece en que planta nos encontramos
	JNB P2.0,PLANTA_0		;Si el sensor de la planta 0 está activo, pasamos al estado 0
	SJMP INIT_EST			;Si el sensor de la planta 0 no está activo, volvemos a ejecutar la subrutina		


PLANTA_0:				;Máquina de eventos de la planta 0
	ACALL ADC			;Llama a la subrutina que hace la conversión analógica digital del puerto 5 y canal 0 (P5.0)
PLANTA_0_SS:				;;Máquina de eventos de la planta 0, una vez comprobado el sobrepeso
	JNB P1.3,BOTON_1_O_2		;Si llaman desde el piso 1, pasamos a la subrutina que llama a las subrutinas necesarias para empezar a subir
	JNB P1.4,BOTON_1_O_2		;Si llaman desde el piso 2, pasamos a la subrutina que llama a las subrutinas necesarias para empezar a subir
	JNB P1.2,BOTON_0		;Si llaman desde el piso 0 o la cabina 0, pasamos a la subrutina que llama a las subrutinas que abren la puerta y temporizan 5 segundos
	JB P0.7,PUERTA_ABIERTA		;Si la puerta está abierta, pasamos a la subrutina que llama a la subrutina que cierra la puerta
	SJMP PLANTA_0			;Si no ocurre ninguno de los eventos anteriores, volvemos a ejecutar la máquina de eventos de la planta 0
BOTON_1_O_2:				;Subrutina que llama a las subrutinas necesarias para empezar a subir
	ACALL CERRAR_PUERTA		;Llama a la subrutina que cierra la puerta
	SETB P2.5			;Pone a 1 el puerto que indica si estamos subiendo o bajando, es decir, estamos subiendo
	MOV A,0FCH			;Mueve el valor del registro del PWM0 al acumulador
	ACALL ACTUALIZAR_DISPLAYS	;Llama a la subrutina que actualiza los displays
	SJMP ACELERANDO			;Salto a la subrutina del estado acelerando
BOTON_0:				;Subrutina que llama a las subrutinas que abren la puerta y temporizan 5 segundos
	ACALL ABRIR_PUERTA		;Llama a la subrutina que abre la puerta
	ACALL TEMPORIZAR_5S		;Llama a la subrutina que temporiza 5 segundos
	SETB P1.2			;Se desactiva el puerto que avisa de las llamadas de la cabina o el piso 0, dando a entender que ya ha sido atendida
	SJMP PLANTA_0			;Después de abrir la puerta y temporizar 5 segundos, volvemos a ejecutar la máquina de eventos de la planta 0
PUERTA_ABIERTA:				;Subrutina que llama a la subrutina que cierra la puerta
	ACALL CERRAR_PUERTA		;Llama a la subrutina que cierra la puerta
	SJMP PLANTA_0			;Después de cerrar la puerta, volvemos a ejecutar la máquina de eventos de la planta 0


	ORG 0053H			;Establece la subrutina de atención a la interrupción de la interrupción provocada por finalizar la conversión del ADC
COMPROBAR_SOBREPESO:			;Subrutina que comprueba si hay sobrepeso
	MOV A,0C6H			;Mueve los 8 bits más significativos al acumulador
	ANL A,#0CDH			;Enmascara todo menos los bits 0,2,3,6 y 7
	SUBB A,#0DCH			;Le resta al acumulador el valor anterior
	JNZ NO_SOBREPESO		;Si el acumulador tras la resta no está a cero, no hay sobrepeso
	SETB 21H			;Ponemos a uno el flag que indica si hay sobrepeso
	ACALL ACTUALIZAR_DISPLAYS	;Llama a la subrutina que actualiza los displays
	SJMP SOBREPESO			;Salto a la subrutina del estado de sobrepeso
NO_SOBREPESO:				;Si no hay sobrepeso
	CLR 21H				;Ponemos a cero el flag que indica si hay sobrepeso
	ACALL ACTUALIZAR_DISPLAYS	;Llama a la subrutina que actualiza los displays
	SJMP PLANTA_0_SS		;Salto a la máquina de eventos de la planta 0


ADC:					;Rutina que hace la conversión analógica digital
	SETB EA				;Se habilitan todas las interrupciones
	ANL 0C5H,#00H			;Limpia el bit ADCI y escoge el canal 5
	ORL 0C5H,#08H			;Pone a 1 el bit ADCS para comenzar la conversión
	SETB 0A8H.6			;Se habilita la interrupción de la conversión del ADC
EOC:					;Rutina que ejecuta la conversión
	MOV A,0C5H			;Mueve el valor del registro ADCON al acumulador
	JNB ACC.4,EOC			;Mira si el valor del bit ADCI es 1 para acabar la conversión


SOBREPESO:				;Máquina de eventos del estado de sobrepeso
	ACALL ADC			;Llama a la subrutina que hace la conversión analógica digital del puerto 5 y canal 0 (P5.0)


ACELERANDO:				;Máquina de eventos del estado acelerando
	JZ ACELERANDO			;Si se ha acabado de acelerar, no se hace nada más
	ACALL TEMPORIZAR_500MS		;Llama a la subrutina que temporiza 500 milisegundos


TEMPORIZAR_500MS:			;Subrutina que temporiza 500 milisegundos
	MOV TMOD,#01H			;Establece el timer 0 en el modo 1, 16 bit
	MOV R7,#99			;99 veces 5 ms = retardo de 495 ms
DELAY_5MS4:				;Subrutina que temporiza 5 milisegundos
	MOV TH0,#HIGH (-10000)		;Necesario para generar el retardo de 5 ms
	MOV TL0,#LOW (-10000)		;Necesario para generar el retardo de 5 ms
	SETB TR0			;Enciende el timer 0
	JNB TF0,$			;Esperar a que el flag del timer 0 se active, indica desbordamiento
	CLR TF0				;Pone a cero el flag de exceso del timer 0
	CLR TR0				;Apaga el timer 0
	DJNZ R7,DELAY_5MS4		;Decrementa R7, repite el retardo de 5 ms si R7 no es cero
	MOV TH0,#HIGH (-10000)		;Necesario para generar el retardo de 5 ms
	MOV TL0,#LOW (-10000)		;Necesario para generar el retardo de 5 ms
	SETB IE.7			;Se habilitan todas las interrupciones
	SETB IE.1			;Se habilita la interrupción del exceso del timer 0
	SETB TR0			;Enciende el timer 0
	JNB TF0,$			;Esperar a que el flag del timer 0 se active, indica desbordamiento		


ACTUALIZAR_DISPLAYS:			;Subrutina que actualiza los displays
	JB 20H,HAY_ERROR		;Si hay un error en la apertura o cierre de la puerta, se indica en los displays
	JB 21H,DP_SOBREPESO		;Si hay sobrepeso cuando el ascensor está parado, se indica en los displays
	SETB P0.0			;Se pone el segmento a del display 7 segmentos a 1
	SETB P0.1			;Se pone el segmento b del display 7 segmentos a 1
	SETB P0.2			;Se pone el segmento c del display 7 segmentos a 1
	SETB P0.3			;Se pone el segmento d del display 7 segmentos a 1
	SETB P0.4			;Se pone el segmento e del display 7 segmentos a 1
	SETB P0.5			;Se pone el segmento f del display 7 segmentos a 1
	CLR P0.6			;Se pone el segmento g del display 7 segmentos a 0
	JNB P1.3,FLECHA_ARRIBA		;Si llaman desde el piso 1, se indica con una flecha hacia arriba
	JNB P1.4,FLECHA_ARRIBA		;Si llaman desde el piso 2, se indica con una flecha hacia arriba
	CLR P3.0			;Se pone el segmento a del display 6 segmentos a 0
	CLR P3.1			;Se pone el segmento b del display 6 segmentos a 0
	SETB P3.2			;Se pone el segmento c del display 6 segmentos a 1
	SETB P3.3			;Se pone el segmento d del display 6 segmentos a 1
	CLR P3.4			;Se pone el segmento e del display 6 segmentos a 0
	CLR P3.5			;Se pone el segmento f del display 6 segmentos a 0
	RET				;Se termina la subrutina
HAY_ERROR:				;Subrutina que indica en los displays que ha habido un error en la apertura o cierre de la puerta
	SETB P0.0			;Se pone el segmento a del display 7 segmentos a 1
	CLR P0.1			;Se pone el segmento b del display 7 segmentos a 0
	CLR P0.2			;Se pone el segmento c del display 7 segmentos a 0
	CLR P0.3			;Se pone el segmento d del display 7 segmentos a 0
	SETB P0.4			;Se pone el segmento e del display 7 segmentos a 1
	SETB P0.5			;Se pone el segmento f del display 7 segmentos a 1
	SETB P0.6			;Se pone el segmento g del display 7 segmentos a 1
	CLR P3.0			;Se pone el segmento a del display 6 segmentos a 0
	CLR P3.1			;Se pone el segmento b del display 6 segmentos a 0
	SETB P3.2			;Se pone el segmento c del display 6 segmentos a 1
	SETB P3.3			;Se pone el segmento d del display 6 segmentos a 1
	CLR P3.4			;Se pone el segmento e del display 6 segmentos a 0
	CLR P3.5			;Se pone el segmento f del display 6 segmentos a 0
	RET				;Se termina la subrutina
DP_SOBREPESO:				;Subrutina que indica en los displays que hay sobrepeso
	SETB P0.0			;Se pone el segmento a del display 7 segmentos a 1
	CLR P0.1			;Se pone el segmento b del display 7 segmentos a 0
	SETB P0.2			;Se pone el segmento c del display 7 segmentos a 1
	SETB P0.3			;Se pone el segmento d del display 7 segmentos a 1
	CLR P0.4			;Se pone el segmento e del display 7 segmentos a 0
	SETB P0.5			;Se pone el segmento f del display 7 segmentos a 1
	SETB P0.6			;Se pone el segmento g del display 7 segmentos a 1
	CLR P3.0			;Se pone el segmento a del display 6 segmentos a 0
	CLR P3.1			;Se pone el segmento b del display 6 segmentos a 0
	CLR P3.2			;Se pone el segmento c del display 6 segmentos a 0
	CLR P3.3			;Se pone el segmento d del display 6 segmentos a 0
	CLR P3.4			;Se pone el segmento e del display 6 segmentos a 0
	CLR P3.5			;Se pone el segmento f del display 6 segmentos a 0
	RET				;Se termina la subrutina
FLECHA_ARRIBA:				;Subrutina que muestra una flecha hacia arriba en el display 6 segmentos
	SETB P3.0			;Se pone el segmento a del display 6 segmentos a 1
	SETB P3.1			;Se pone el segmento b del display 6 segmentos a 1
	SETB P3.2			;Se pone el segmento c del display 6 segmentos a 1
	SETB P3.3			;Se pone el segmento d del display 6 segmentos a 1
	CLR P3.4			;Se pone el segmento e del display 6 segmentos a 0
	CLR P3.5			;Se pone el segmento f del display 6 segmentos a 0
	RET				;Se termina la subrutina


CERRAR_PUERTA:				;Subrutina que cierra la puerta y comprueba si tras 5 segundos, la puerta está cerrada
	CLR P1.0			;Pone a 0 el primer puerto necesario para el control de la puerta
	SETB P1.1			;Pone a 1 el segundo puerto necesario para el control de la puerta
	ACALL COMPROBAR_PC		;Llama a la subrutina que comprueba durante 5 segundos si la puerta se ha cerrado
	JB P0.7,ERROR			;Si la puerta sigue abierta tras los 5 segundos, se pasa a la subrutina de error
	RET				;Se termina la subrutina


ABRIR_PUERTA:				;Subrutina que abre la puerta y comprueba si tras 5 segundos, la puerta está abierta
	SETB P1.0			;Pone a 1 el primer puerto necesario para el control de la puerta
	CLR P1.1			;Pone a 0 el segundo puerto necesario para el control de la puerta
	ACALL COMPROBAR_PA		;Llama a la subrutina que comprueba durante 5 segundos si la puerta se ha abierto
	JNB P0.7,ERROR			;Si la puerta sigue cerrada tras los 5 segundos, se pasa a la subrutina de error
	RET				;Se termina la subrutina


TEMPORIZAR_5S:				;Subrutina que temporiza 5 segundos
	MOV TMOD,#01H			;Establece el timer 0 en el modo 1, 16 bit
	MOV R6,#10			;10 veces 500 ms = retardo de 5 s
DELAY_500MS:				;Subrutina que temporiza 500 milisegundos
	MOV R7,#100			;100 veces 5 ms = retardo de 500 ms
DELAY_5MS:				;Subrutina que temporiza 5 milisegundos
	MOV TH0,#HIGH (-10000)		;Necesario para generar el retardo de 5 ms
	MOV TL0,#LOW (-10000)		;Necesario para generar el retardo de 5 ms
	SETB TR0			;Enciende el timer 0
	JNB TF0,$			;Esperar a que el flag del timer 0 se active, indica desbordamiento
	CLR TF0				;Pone a cero el flag de exceso del timer 0
	CLR TR0				;Apaga el timer 0
	DJNZ R7,DELAY_5MS		;Decrementa R7, repite el retardo de 5 ms si R7 no es cero
	DJNZ R6,DELAY_500MS		;Decrementa R6, recarga R7 si R6 no es cero
	RET				;Se termina la subrutina


COMPROBAR_PC:				;Subrutina que comprueba durante 5 segundos si la puerta se ha cerrado
	MOV TMOD,#01H			;Establece el timer 0 en el modo 1, 16 bit
	MOV R6,#10			;10 veces 500 ms = retardo de 5 s
DELAY_500MS2:				;Subrutina que temporiza 500 milisegundos
	MOV R7,#100			;100 veces 5 ms = retardo de 500 ms
DELAY_5MS2:				;Subrutina que temporiza 5 milisegundos
	MOV TH0,#HIGH (-10000)		;Necesario para generar el retardo de 5 ms
	MOV TL0,#LOW (-10000)		;Necesario para generar el retardo de 5 ms
	SETB TR0			;Enciende el timer 0
	JNB TF0,$			;Esperar a que el flag del timer 0 se active, indica desbordamiento
	CLR TF0				;Pone a cero el flag de exceso del timer 0
	CLR TR0				;Apaga el timer 0
	JNB P0.7,PUERTA_CERRADA		;Si la puerta está cerrada, termina la subrutina
	DJNZ R7,DELAY_5MS2		;Decrementa R7, repite el retardo de 5 ms si R7 no es cero
	DJNZ R6,DELAY_500MS2		;Decrementa R6, recarga R7 si R6 no es cero
PUERTA_CERRADA:				;Salto al final de la subrutina
	RET				;Se termina la subrutina


COMPROBAR_PA:				;Subrutina que comprueba durante 5 segundos si la puerta se ha abierto
	MOV TMOD,#01H			;Establece el timer 0 en el modo 1, 16 bit
	MOV R6,#10			;10 veces 500 ms = retardo de 5 s
DELAY_500MS3:				;Subrutina que temporiza 500 milisegundos
	MOV R7,#100			;100 veces 5 ms = retardo de 500 ms
DELAY_5MS3:				;Subrutina que temporiza 5 milisegundos
	MOV TH0,#HIGH (-10000)		;Necesario para generar el retardo de 5 ms
	MOV TL0,#LOW (-10000)		;Necesario para generar el retardo de 5 ms
	SETB TR0			;Enciende el timer 0
	JNB TF0,$			;Esperar a que el flag del timer 0 se active, indica desbordamiento
	CLR TF0				;Pone a cero el flag de exceso del timer 0
	CLR TR0				;Apaga el timer 0
	JB P0.7,PUERTA_ABIERTA2		;Si la puerta está abierta, termina la subrutina
	DJNZ R7,DELAY_5MS3		;Decrementa R7, repite el retardo de 5 ms si R7 no es cero
	DJNZ R6,DELAY_500MS3		;Decrementa R6, recarga R7 si R6 no es cero
PUERTA_ABIERTA2:			;Salto al final de la subrutina
	RET				;Se termina la subrutina


ERROR:					;Subrutina de error
	SETB 20H			;Se pone el flag de error a 1
	ACALL ACTUALIZAR_DISPLAYS	;Llama a la subrutina que actualiza los displays
	SJMP FINAL			;Salto al final del programa


FINAL:					;Etiqueta que te lleva al final del programa
	END				;Final del programa
