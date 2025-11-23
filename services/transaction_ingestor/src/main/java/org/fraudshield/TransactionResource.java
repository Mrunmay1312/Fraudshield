package org.fraudshield;

import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Consumes;
import javax.ws.rs.core.MediaType;
import org.apache.kafka.clients.producer.*;
import java.util.Properties;
import javax.annotation.PostConstruct;
import javax.enterprise.context.ApplicationScoped;

@ApplicationScoped
@Path("/ingest")
public class TransactionResource {

    private Producer<String, String> producer;

    @PostConstruct
    public void init() {
        Properties props = new Properties();
        props.put("bootstrap.servers", System.getenv().getOrDefault("KAFKA_BOOTSTRAP", "kafka:9092"));
        props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        producer = new KafkaProducer<>(props);
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    public String ingest(String payload) {
        ProducerRecord<String, String> rec = new ProducerRecord<>("transactions", null, payload);
        producer.send(rec);
        return "{\"status\":\"sent\"}";
    }
}
