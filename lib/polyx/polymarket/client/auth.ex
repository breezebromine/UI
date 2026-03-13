defmodule Polyx.Polymarket.Client.Auth do
  @moduledoc """
  Authentication for Polymarket CLOB API.
  Handles L2 HMAC signature generation for authenticated requests.

  The POLY_ADDRESS header is derived from the private key (matching the
  Python py_clob_client behaviour) so that it is always the correct
  EIP-55 checksummed address for the signer who created the API credentials.
  """

  require Logger

  @doc """
  Add L2 auth headers for GET requests.
  """
  def add_l2_auth_headers(headers, method, request_path, _params, timestamp, config) do
    api_key = config[:api_key]
    api_secret = config[:api_secret]
    passphrase = config[:api_passphrase]
    private_key = config[:private_key]

    # Derive the signer address from the private key (EIP-55 checksummed),
    # exactly like the Python client does with eth_account.Account.from_key().
    auth_address = derive_checksummed_address(private_key)

    if api_key && api_secret && passphrase && auth_address do
      message = timestamp <> method <> request_path

      signature = generate_signature(api_secret, message)

      Logger.debug("HMAC message: #{message}")
      Logger.debug("HMAC signature: #{signature}")
      Logger.debug("Auth address (derived from private key): #{auth_address}")

      headers ++
        [
          {"POLY_ADDRESS", auth_address},
          {"POLY_SIGNATURE", signature},
          {"POLY_TIMESTAMP", timestamp},
          {"POLY_API_KEY", api_key},
          {"POLY_PASSPHRASE", passphrase}
        ]
    else
      Logger.warning(
        "Missing API credentials: key=#{!!api_key}, secret=#{!!api_secret}, pass=#{!!passphrase}, private_key=#{!!private_key}"
      )

      headers
    end
  end

  @doc """
  Add L2 auth headers for POST requests (includes body in signature).
  """
  def add_l2_auth_headers_post(headers, method, request_path, body, timestamp, config) do
    api_key = config[:api_key]
    api_secret = config[:api_secret]
    passphrase = config[:api_passphrase]
    private_key = config[:private_key]

    auth_address = derive_checksummed_address(private_key)

    if api_key && api_secret && passphrase && auth_address do
      message = timestamp <> method <> request_path <> body

      signature = generate_signature(api_secret, message)

      Logger.debug("HMAC POST message: #{String.slice(message, 0, 200)}...")
      Logger.debug("HMAC signature: #{signature}")

      headers ++
        [
          {"POLY_ADDRESS", auth_address},
          {"POLY_SIGNATURE", signature},
          {"POLY_TIMESTAMP", timestamp},
          {"POLY_API_KEY", api_key},
          {"POLY_PASSPHRASE", passphrase}
        ]
    else
      Logger.warning("Missing API credentials for POST request")
      headers
    end
  end

  # Private functions

  defp generate_signature(api_secret, message) do
    # Decode secret - try URL-safe first, then standard base64
    secret =
      case Base.url_decode64(api_secret, padding: false) do
        {:ok, decoded} -> decoded
        :error -> Base.decode64!(api_secret)
      end

    # Create HMAC-SHA256 signature and encode with URL-safe base64 (with padding)
    :crypto.mac(:hmac, :sha256, secret, message)
    |> Base.url_encode64()
  end

  # Derive the Ethereum address from a private key and apply EIP-55 checksum.
  # This matches the Python client's `signer.address()` which always returns
  # the checksummed address derived from the private key.
  defp derive_checksummed_address(nil), do: nil
  defp derive_checksummed_address(""), do: nil

  defp derive_checksummed_address(private_key) do
    private_key_bytes =
      private_key
      |> String.replace_prefix("0x", "")
      |> Base.decode16!(case: :mixed)

    # Derive uncompressed public key (65 bytes: 0x04 prefix + 32-byte X + 32-byte Y)
    {:ok, public_key} = ExSecp256k1.create_public_key(private_key_bytes)
    <<4, public_key_xy::binary-size(64)>> = public_key

    # Ethereum address = last 20 bytes of keccak256(public_key_xy)
    <<_::binary-size(12), address_bytes::binary-size(20)>> =
      ExKeccak.hash_256(public_key_xy)

    # Apply EIP-55 mixed-case checksum
    hex_lower = Base.encode16(address_bytes, case: :lower)
    "0x" <> eip55_checksum(hex_lower)
  end

  # EIP-55: capitalise hex character when the corresponding nibble in
  # keccak256(lowercase_hex_address) is >= 8.
  defp eip55_checksum(hex_lower) do
    hash = ExKeccak.hash_256(hex_lower) |> Base.encode16(case: :lower)

    hex_lower
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.map(fn {char, i} ->
      if String.at(hash, i) in ["8", "9", "a", "b", "c", "d", "e", "f"] do
        String.upcase(char)
      else
        char
      end
    end)
    |> Enum.join()
  end
end
