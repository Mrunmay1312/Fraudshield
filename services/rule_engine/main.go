package main

import (
	"net/http"
	"github.com/gin-gonic/gin"
)

type RuleRequest struct {
	TransactionID string  `json:"transaction_id"`
	Amount        float64 `json:"amount"`
	UserID        string  `json:"user_id"`
	RiskScore     float64 `json:"risk_score"`
}

type RuleResponse struct {
	TransactionID string `json:"transaction_id"`
	Action        string `json:"action"`
	Reason        string `json:"reason"`
}

func main() {
	r := gin.Default()

	r.POST("/evaluate", func(c *gin.Context) {
		var req RuleRequest
		if err := c.BindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		response := RuleResponse{
			TransactionID: req.TransactionID,
		}

		// basic example rules
		if req.RiskScore > 0.85 {
			response.Action = "REJECT"
			response.Reason = "High risk score"
		} else if req.Amount > 50000 {
			response.Action = "MANUAL_REVIEW"
			response.Reason = "High transaction amount"
		} else {
			response.Action = "APPROVE"
			response.Reason = "All checks passed"
		}

		c.JSON(http.StatusOK, response)
	})

	r.Run(":7000")
}

