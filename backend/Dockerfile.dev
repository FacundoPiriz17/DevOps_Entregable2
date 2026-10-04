FROM maven:3.9-eclipse-temurin-26

WORKDIR /app

COPY pom.xml ./

RUN mvn -q -DskipTests dependency:go-offline

COPY src ./src

EXPOSE 8080

CMD ["mvn", "spring-boot:run", "-DskipTests"]