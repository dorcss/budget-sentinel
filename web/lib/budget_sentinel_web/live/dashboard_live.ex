defmodule BudgetSentinelWeb.DashboardLive do
  use BudgetSentinelWeb, :live_view

  alias BudgetSentinel.Accounts.User
  alias BudgetSentinel.{Audit, Intelligence.AnalysisPipeline, Procurement}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BudgetSentinel.PubSub, AnalysisPipeline.topic())
    end

    {:ok, assign_dashboard_data(socket, scanning: false)}
  end

  @impl true
  def handle_event("run_scan", _params, socket) do
    if User.can_manage?(socket.assigns.current_user) do
      topic = AnalysisPipeline.topic()

      Task.Supervisor.start_child(BudgetSentinel.TaskSupervisor, fn ->
        try do
          AnalysisPipeline.run_detection_scan()
        rescue
          e ->
            require Logger
            Logger.error("[DashboardLive] scan task crashed: #{inspect(e)}")
            Phoenix.PubSub.broadcast(BudgetSentinel.PubSub, topic, {:scan_completed, 0})
        end
      end)

      Process.send_after(self(), :scan_timeout, 60_000)
      {:noreply, assign(socket, scanning: true)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to run a detection scan.")}
    end
  end

  @impl true
  def handle_info({:scan_completed, _count}, socket) do
    {:noreply, assign_dashboard_data(socket, scanning: false)}
  end

  def handle_info(:scan_timeout, socket) do
    if socket.assigns.scanning do
      {:noreply, socket |> assign(scanning: false) |> put_flash(:error, "Scan timed out — please try again.")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:anomaly_detected, _anomaly}, socket) do
    {:noreply, assign_dashboard_data(socket, scanning: socket.assigns.scanning)}
  end

  def handle_info({:report_generated, _anomaly_id, _report}, socket) do
    {:noreply, assign_dashboard_data(socket, scanning: socket.assigns.scanning)}
  end

  defp assign_dashboard_data(socket, scanning: scanning) do
    user = socket.assigns.current_user
    projects = Procurement.list_projects(user)
    anomalies = Audit.list_anomalies(user, status: "open", limit: 10)
    alerts = Audit.list_alerts(user, []) |> Enum.take(5)
    failed_alerts_count = Audit.count_failed_alerts(user)

    socket
    |> assign(:projects, projects)
    |> assign(:total_projects, length(projects))
    |> assign(:anomalies, anomalies)
    |> assign(:high_risk_count, Audit.count_open_high_risk(user))
    |> assign(:alerts, alerts)
    |> assign(:failed_alerts_count, failed_alerts_count)
    |> assign(:scanning, scanning)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-heading">
      <h1>Gasabo District — Roads &amp; Infrastructure Oversight</h1>
      <button :if={User.can_manage?(@current_user)} class="btn btn--secondary" phx-click="run_scan" disabled={@scanning}>
        <%= if @scanning, do: "Scanning...", else: "Run Detection Scan" %>
      </button>
    </div>

    <div class="stat-row">
      <.stat_card label="Monitored Projects" value={@total_projects} />
      <.stat_card label="Anomalies (recent)" value={length(@anomalies)} accent="secondary" />
      <.stat_card label="High-Risk Open" value={@high_risk_count} accent="secondary" />
      <.stat_card label="Failed Alerts" value={@failed_alerts_count} accent="secondary" />
    </div>

    <div class="card">
      <h2>Project Budget Health</h2>
      <table class="data-table">
        <thead>
          <tr>
            <th>Project</th>
            <th>Project Type</th>
            <th>Budget Utilization</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={project <- @projects}>
            <td><.link navigate={~p"/projects/#{project.id}"}><%= project.name %></.link></td>
            <td><%= project.sector |> String.replace("_", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1) %></td>
            <td><.budget_bar percent={Procurement.budget_utilization_percent(project)} /></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Recent Anomalies</h2>
      <div :if={@anomalies == []} class="empty-state">
        No anomalies detected yet. Run a detection scan to analyze current expenditures.
      </div>
      <table :if={@anomalies != []} class="data-table">
        <thead>
          <tr>
            <th>Project</th>
            <th>Fraud Type</th>
            <th>Risk Score</th>
            <th>Detected</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={anomaly <- @anomalies}>
            <td><.link navigate={~p"/anomalies/#{anomaly.id}"}><%= anomaly.project.name %></.link></td>
            <td><.fraud_type_label fraud_type={anomaly.fraud_type} /></td>
            <td><.risk_badge severity={anomaly.severity} risk_score={anomaly.risk_score} /></td>
            <td><%= Calendar.strftime(anomaly.detected_at, "%Y-%m-%d %H:%M") %></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <div class="page-heading">
        <h2>Recent Alerts</h2>
        <.link navigate={~p"/alerts"} class="btn--link">View all</.link>
      </div>
      <div :if={@alerts == []} class="empty-state">
        No alerts dispatched yet.
      </div>
      <table :if={@alerts != []} class="data-table">
        <thead>
          <tr>
            <th>Recipient</th>
            <th>Project</th>
            <th>Status</th>
            <th>Dispatched At</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={alert <- @alerts}>
            <td><%= alert.recipient %></td>
            <td><.link navigate={~p"/anomalies/#{alert.anomaly_id}"}><%= alert.anomaly.project.name %></.link></td>
            <td><span class={["alert-status", "alert-status--#{alert.status}"]}><%= String.capitalize(alert.status) %></span></td>
            <td><%= alert.dispatched_at && Calendar.strftime(alert.dispatched_at, "%Y-%m-%d %H:%M") %></td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
