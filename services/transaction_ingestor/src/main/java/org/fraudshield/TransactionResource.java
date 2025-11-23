package org.fraudshield;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.annotation.PostConstruct;

@Path("/transactions")
@ApplicationScoped
public class TransactionResource {

    @PostConstruct
    void init() {
        // Initialization logic if needed
        System.out.println("TransactionResource initialized");
    }

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response getSampleTransaction() {
        // Example response
        String sample = "{ \"id\": 1, \"amount\": 100.0, \"status\": \"OK\" }";
        return Response.ok(sample).build();
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response ingestTransaction(String transactionJson) {
        // TODO: Process transaction and push to Kafka
        System.out.println("Received transaction: " + transactionJson);

        // Return acknowledgement
        String response = "{ \"status\": \"received\" }";
        return Response.ok(response).build();
    }
}

