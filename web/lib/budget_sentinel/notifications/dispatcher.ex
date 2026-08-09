defmodule BudgetSentinel.Notifications.Dispatcher do
  @moduledoc """
  Decides which oversight officers receive a high-risk anomaly email and
  logs the outcome as an Alert record.
  """

  alias BudgetSentinel.{Accounts, Audit}
  alias BudgetSentinel.Notifications.{AlertEmail, Mailer}

  @doc """
  Dispatches a high-risk anomaly alert to every admin and to the oversight
  officers/auditors assigned to the anomaly's ministry.
  """
  def dispatch(anomaly, report, project) do
    recipients = Accounts.list_alert_recipients(project.ministry_id)

    Enum.each(recipients, fn recipient ->
      email = AlertEmail.high_risk_alert(anomaly, report, recipient)

      try do
        case Mailer.deliver(email) do
          {:ok, _metadata} ->
            Audit.log_alert(anomaly, recipient, "sent")

          {:error, reason} ->
            require Logger
            Logger.error("[Dispatcher] email to #{recipient} failed: #{inspect(reason)}")
            Audit.log_alert(anomaly, recipient, "failed")
        end
      rescue
        e ->
          require Logger
          Logger.error("[Dispatcher] email to #{recipient} crashed: #{inspect(e)}")
          Audit.log_alert(anomaly, recipient, "failed")
      end
    end)
  end

  @doc "Retries delivery for a previously failed alert, updating its status in place."
  def retry(alert) do
    %{anomaly: anomaly} = alert

    case anomaly.audit_report do
      nil ->
        Audit.update_alert_status(alert, "failed")

      report ->
        email = AlertEmail.high_risk_alert(anomaly, report, alert.recipient)

        try do
          case Mailer.deliver(email) do
            {:ok, _metadata} ->
              Audit.update_alert_status(alert, "sent")

            {:error, reason} ->
              require Logger
              Logger.error("[Dispatcher] retry to #{alert.recipient} failed: #{inspect(reason)}")
              Audit.update_alert_status(alert, "failed")
          end
        rescue
          e ->
            require Logger
            Logger.error("[Dispatcher] retry to #{alert.recipient} crashed: #{inspect(e)}")
            Audit.update_alert_status(alert, "failed")
        end
    end
  end
end
