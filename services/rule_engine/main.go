package main

import (
    "encoding/json"
    "net/http"
    "strconv"
    "log"
)

type Transaction struct {
    TransactionID string  `json:"transaction_id"`
    Amount float64 `json:"amount"`
    CardID string `json:"card_id"`
}

type Decision struct {
    TransactionID string `json:"transaction_id"`
    IsFraud bool `json:"is_fraud"`
    Reason string `json:"reason"`
}

func ruleHandler(w http.ResponseWriter, r *http.Request) {
    var tx Transaction
    decoder := json.NewDecoder(r.Body)
    err := decoder.Decode(&tx)
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    isFraud := false
    reason := "ok"
    if tx.Amount > 5000 {
        isFraud = true
        reason = "amount_threshold"
    }
    if tx.Amount <= 0 {
        isFraud = true
        reason = "invalid_amount"
    }
    dec := Decision{TransactionID: tx.TransactionID, IsFraud: isFraud, Reason: reason}
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(dec)
}

func main() {
    http.HandleFunc("/rule", ruleHandler)
    port := 8080
    log.Println("Rule engine listening on :" + strconv.Itoa(port))
    log.Fatal(http.ListenAndServe(":" + strconv.Itoa(port), nil))
}
