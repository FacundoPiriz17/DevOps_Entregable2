/**
 * @file DevopsBackendApplication.java
 * @brief Punto de entrada principal de la aplicación backend.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * @brief Clase principal que inicializa la aplicación Spring Boot.
 *
 */
@SpringBootApplication
public class DevopsBackendApplication {

	/**
	 * @brief Inicia la aplicación Spring Boot.
	 *
	 * @param args argumentos recibidos al iniciar la aplicación.
	 * @return no devuelve ningún valor.
	 */
	public static void main(String[] args) {
		SpringApplication.run(DevopsBackendApplication.class, args);
	}

}
