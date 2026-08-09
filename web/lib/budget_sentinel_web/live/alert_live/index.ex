defmodule BudgetSentinelWeb.AlertLive.Index do
  use BudgetSentinelWeb, :live_view

  alias BudgetSentinel.Accounts.User
  alias BudgetSentinel.{Audit, Notifications.Dispatcher}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, status_filter: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    status_filter = params["status"]

    alerts =
      Audit.list_alerts(
        socket.assigns.current_user,
        if(status_filter, do: [status: status_filter], else: [])
      )

    {:noreply, assign(socket, alerts: alerts, status_filter: status_filter)}
  end

  @impl true
  def handle_event("retry", %{"id" => id}, socket) do
    if User.can_manage?(socket.assigns.current_user) do
      alert = Audit.get_alert!(id)
      pid = self()

      Task.start(fn ->
        Dispatcher.retry(alert)
        send(pid, {:retry_done, alert.id})
      end)

      {:noreply, put_flash(socket, :info, "Retrying alert to #{alert.recipient}…")}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to retry alerts.")}
    end
  end

  @impl true
  def handle_info({:retry_done, _alert_id}, socket) do
    alerts =
      Audit.list_alerts(
        socket.assigns.current_user,
        if(socket.assigns.status_filter, do: [status: socket.assigns.status_filter], else: [])
      )

    {:noreply, assign(socket, :alerts, alerts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-heading">
      <h1>Alerts Center</h1>
      <div class="filter-tabs">
        <.link patch={~p"/alerts"} class={["filter-tab", @status_filter == nil && "filter-tab--active"]}>All</.link>
        <.link patch={~p"/alerts?status=sent"} class={["filter-tab", @status_filter == "sent" && "filter-tab--active"]}>Sent</.link>
        <.link patch={~p"/alerts?status=failed"} class={["filter-tab", @status_filter == "failed" && "filter-tab--active"]}>Failed</.link>
        <.link patch={~p"/alerts?status=pending"} class={["filter-tab", @status_filter == "pending" && "filter-tab--active"]}>Pending</.link>
      </div>
    </div>

    <div class="card">
      <div :if={@alerts == []} class="empty-state">
        No alerts dispatched yet. High-risk anomalies automatically generate alerts when detected.
      </div>
      <table :if={@alerts != []} class="data-table">
        <thead>
          <tr>
            <th>Recipient</th>
            <th>Project</th>
            <th>Fraud Type</th>
            <th>Status</th>
            <th>Dispatched At</th>
            <th :if={User.can_manage?(@current_user)}>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={alert <- @alerts}>
            <td><%= alert.recipient %></td>
            <td><.link navigate={~p"/anomalies/#{alert.anomaly_id}"}><%= alert.anomaly.project.name %></.link></td>
            <td><.fraud_type_label fraud_type={alert.anomaly.fraud_type} /></td>
            <td><span class={["alert-status", "alert-status--#{alert.status}"]}><%= String.capitalize(alert.status) %></span></td>
            <td><%= alert.dispatched_at && Calendar.strftime(alert.dispatched_at, "%Y-%m-%d %H:%M") %></td>
            <td :if={User.can_manage?(@current_user)}>
              <button :if={alert.status == "failed"} class="btn--link" phx-click="retry" phx-value-id={alert.id}>
                Retry
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
