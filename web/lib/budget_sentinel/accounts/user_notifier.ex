defmodule BudgetSentinel.Accounts.UserNotifier do
  import Swoosh.Email

  alias BudgetSentinel.Notifications.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    from_addr = System.get_env("MAIL_FROM") || System.get_env("SMTP_USERNAME") || "onboarding@resend.dev"
    email =
      new()
      |> to(recipient)
      |> from({"Budget Sentinel", from_addr})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver an invitation to a newly-invited user, telling them their role
  and ministry scope and linking them to set their own password.
  """
  def deliver_invite_instructions(user, url) do
    role = user.role |> String.replace("_", " ") |> String.capitalize()

    scope =
      case user.ministry do
        nil -> "All ministries (administrator access)"
        ministry -> ministry.name
      end

    text_body = """

    ==============================

    Hi #{user.email},

    You have been invited to join BudgetSentinel, the government expenditure
    monitoring and anomaly detection platform.

    Role: #{role}
    Scope: #{scope}

    Accept your invitation and set your password by visiting the URL below.
    This link expires in 14 days.

    #{url}

    If you weren't expecting this invitation, you can ignore this email.

    ==============================
    """

    deliver_html(
      user.email,
      "You've been invited to BudgetSentinel",
      text_body,
      invite_html(user.email, role, scope, url)
    )
  end

  defp invite_html(email, role, scope, url) do
    """
    <!doctype html>
    <html lang="en">
      <body style="margin:0; padding:0; background:#f4f6f9; font-family:'Segoe UI', Arial, Helvetica, sans-serif;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9; padding:32px 16px;">
          <tr>
            <td align="center">
              <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px; width:100%; background:#ffffff; border-radius:10px; border:1px solid #e1e6ed; overflow:hidden;">
                <tr>
                  <td style="background:#13294b; padding:22px 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="width:32px; height:32px; background:#d4a24c; border-radius:6px; text-align:center; vertical-align:middle; font-weight:700; font-size:13px; color:#13294b; font-family:'Segoe UI', Arial, sans-serif;">BS</td>
                        <td style="padding-left:12px; color:#ffffff; font-size:17px; font-weight:600; vertical-align:middle;">BudgetSentinel</td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td style="padding:36px 32px 28px;">
                    <h1 style="margin:0 0 10px; font-size:21px; line-height:1.3; color:#13294b; font-weight:700;">You've been invited</h1>
                    <p style="margin:0 0 26px; font-size:14px; line-height:1.6; color:#5b6577;">
                      Hi #{html_escape(email)}, you've been invited to join <strong style="color:#1c2230;">BudgetSentinel</strong>,
                      the government expenditure monitoring and anomaly detection platform.
                    </p>

                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9; border-radius:8px; margin-bottom:28px;">
                      <tr>
                        <td style="padding:18px 22px;">
                          <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                            <tr>
                              <td style="padding-bottom:14px;">
                                <span style="display:block; font-size:11px; font-weight:700; letter-spacing:0.04em; text-transform:uppercase; color:#5b6577;">Role</span>
                                <span style="display:block; font-size:15px; font-weight:600; color:#1c2230; margin-top:2px;">#{html_escape(role)}</span>
                              </td>
                            </tr>
                            <tr>
                              <td>
                                <span style="display:block; font-size:11px; font-weight:700; letter-spacing:0.04em; text-transform:uppercase; color:#5b6577;">Scope</span>
                                <span style="display:block; font-size:15px; font-weight:600; color:#1c2230; margin-top:2px;">#{html_escape(scope)}</span>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>

                    <table role="presentation" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="border-radius:8px; background:#13294b;">
                          <a href="#{html_escape(url)}" style="display:inline-block; padding:13px 30px; font-size:14px; font-weight:600; color:#ffffff; text-decoration:none; border-radius:8px;">
                            Accept Invitation &amp; Set Password
                          </a>
                        </td>
                      </tr>
                    </table>

                    <p style="margin:26px 0 0; font-size:12.5px; line-height:1.6; color:#5b6577;">
                      This link expires in <strong>14 days</strong>. If the button above doesn't work, copy and paste this URL into your browser:<br>
                      <a href="#{html_escape(url)}" style="color:#13294b; word-break:break-all;">#{html_escape(url)}</a>
                    </p>
                    <p style="margin:18px 0 0; font-size:12.5px; line-height:1.6; color:#5b6577;">
                      If you weren't expecting this invitation, you can safely ignore this email.
                    </p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 32px; background:#f4f6f9; border-top:1px solid #e1e6ed;">
                    <p style="margin:0; font-size:11px; color:#5b6577;">
                      BudgetSentinel &mdash; Government Public Project Expenditure Tracking and Anomaly Detection System
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end

  defp html_escape(value), do: value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp deliver_html(recipient, subject, text_body, html_body) do
    from_addr = System.get_env("MAIL_FROM") || System.get_env("SMTP_USERNAME") || "onboarding@resend.dev"
    email =
      new()
      |> to(recipient)
      |> from({"Budget Sentinel", from_addr})
      |> subject(subject)
      |> text_body(text_body)
      |> html_body(html_body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
