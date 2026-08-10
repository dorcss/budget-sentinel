defmodule BudgetSentinel.Notifications.AlertEmail do
  import Swoosh.Email

  alias BudgetSentinel.Audit.{Anomaly, AuditReport}

  def high_risk_alert(%Anomaly{} = anomaly, %AuditReport{} = report, recipient) do
    new()
    |> to(recipient)
    |> from({"Budget Sentinel", System.get_env("MAIL_FROM") || System.get_env("SMTP_USERNAME") || "onboarding@resend.dev"})
    |> subject("[BudgetSentinel] High-risk anomaly detected: #{humanize(anomaly.fraud_type)}")
    |> text_body(body(anomaly, report))
  end

  defp body(anomaly, report) do
    """
    A high-risk expenditure anomaly has been detected and requires review.

    Fraud type: #{humanize(anomaly.fraud_type)}
    Risk score: #{anomaly.risk_score}/100 (#{anomaly.severity} severity)

    Summary
    #{report.summary}

    Severity assessment
    #{report.severity_assessment}

    Recommended actions
    #{report.recommended_actions}

    -- BudgetSentinel automated oversight system
    """
  end

  defp humanize(fraud_type), do: String.replace(fraud_type, "_", " ")
end
