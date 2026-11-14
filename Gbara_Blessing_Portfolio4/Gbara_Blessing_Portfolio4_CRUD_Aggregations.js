// MongoDB Aggregation Pipelines for PayBridge Fraud Telemetry
// Student: Blessing Gbara (301832255)

// 1. Pipeline 1: High Severity Fraud Queue by Channel
db.fraud_alert_evidence.aggregate([
  { $match: { severity: { $in: ["HIGH", "CRITICAL"] } } },
  { $group: {
      _id: "$channel",
      totalAlerts: { $sum: 1 },
      avgRiskScore: { $avg: "$features.deviceRiskScore" },
      totalFlaggedAmount: { $sum: "$features.amount" }
  }},
  { $sort: { totalAlerts: -1 } }
]);

// 2. Pipeline 2: Velocity Rule Hits and Resolution Status
db.fraud_alert_evidence.aggregate([
  { $match: { "rule.code": "VELOCITY_5M" } },
  { $group: {
      _id: "$status",
      count: { $sum: 1 },
      avgAttempts: { $avg: "$features.recentAttempts" }
  }},
  { $project: {
      status: "$_id",
      count: 1,
      avgAttempts: { $round: ["$avgAttempts", 2] },
      _id: 0
  }}
]);
