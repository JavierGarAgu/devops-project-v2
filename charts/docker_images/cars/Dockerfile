# Etapa de construcción
# Imagen base
FROM maven:3.9.6-eclipse-temurin-17 AS construccion
# Establecer el directorio de trabajo
WORKDIR /app
# Copio el proyecto al contenedor
COPY pom.xml .
COPY src ./src
# Compilo el proyecto
RUN mvn clean package -DskipTests

# Etapa de ejecución
# Imagen base para la ejecución
FROM eclipse-temurin:17-jre-alpine
# Establecer el directorio de trabajo
WORKDIR /app
# Copio el archivo JAR construido desde la etapa de construcción
COPY --from=construccion /app/target/*.jar app.jar
# Exponer el puerto en el que la aplicación escuchará
EXPOSE 8080
# Comando para ejecutar la aplicación
ENTRYPOINT ["java", "-jar", "app.jar"]