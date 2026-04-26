defmodule Exy.Prompts do
  @moduledoc false

  @system_path Application.app_dir(:exy, "priv/prompts/system.md")
  @summarization_system_path Application.app_dir(:exy, "priv/prompts/summarization_system.md")
  @context_summary_path Application.app_dir(:exy, "priv/prompts/context_summary.md")
  @context_update_path Application.app_dir(:exy, "priv/prompts/context_update.md")
  @turn_prefix_summary_path Application.app_dir(:exy, "priv/prompts/turn_prefix_summary.md")

  @external_resource @system_path
  @external_resource @summarization_system_path
  @external_resource @context_summary_path
  @external_resource @context_update_path
  @external_resource @turn_prefix_summary_path

  @system File.read!(@system_path)
  @summarization_system File.read!(@summarization_system_path)
  @context_summary File.read!(@context_summary_path)
  @context_update File.read!(@context_update_path)
  @turn_prefix_summary File.read!(@turn_prefix_summary_path)

  @spec system() :: String.t()
  def system, do: Application.get_env(:exy, :system_prompt, @system)

  @spec summarization_system() :: String.t()
  def summarization_system, do: @summarization_system

  @spec context_summary() :: String.t()
  def context_summary, do: @context_summary

  @spec context_update() :: String.t()
  def context_update, do: @context_update

  @spec turn_prefix_summary() :: String.t()
  def turn_prefix_summary, do: @turn_prefix_summary
end
