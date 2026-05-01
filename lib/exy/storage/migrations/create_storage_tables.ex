defmodule Exy.Storage.Migrations.CreateStorageTables do
  @moduledoc "Internal implementation module."
  use Ecto.Migration

  def change do
    create_if_not_exists table(:sessions, primary_key: false) do
      add(:id, :text, primary_key: true)
      add(:cwd, :text)
      add(:model, :text)
      add(:title, :text)
      add(:status, :text, null: false, default: "idle")
      add(:started_at, :utc_datetime_usec, null: false)
      add(:updated_at, :utc_datetime_usec, null: false)
      add(:ended_at, :utc_datetime_usec)
      add(:message_count, :integer, null: false, default: 0)
      add(:first_message_preview, :text)
      add(:last_message_preview, :text)
      add(:usage_input_tokens, :integer, null: false, default: 0)
      add(:usage_output_tokens, :integer, null: false, default: 0)
      add(:usage_total_tokens, :integer, null: false, default: 0)
      add(:usage_total_cost, :float, null: false, default: 0.0)
    end

    create_if_not_exists(index(:sessions, [:updated_at]))
    create_if_not_exists(index(:sessions, [:status]))

    create_if_not_exists table(:ui_events) do
      add(:session_id, :text, null: false)
      add(:seq, :integer, null: false)
      add(:event_id, :text, null: false)
      add(:type, :text, null: false)
      add(:at, :utc_datetime_usec, null: false)
      add(:data, :map, null: false)
    end

    create_if_not_exists(unique_index(:ui_events, [:session_id, :seq]))
    create_if_not_exists(index(:ui_events, [:session_id, :at]))
    create_if_not_exists(index(:ui_events, [:type]))

    create_if_not_exists table(:trajectory_events) do
      add(:session_id, :text)
      add(:event_id, :text, null: false)
      add(:type, :text, null: false)
      add(:at, :utc_datetime_usec, null: false)
      add(:data, :map, null: false)
    end

    create_if_not_exists(unique_index(:trajectory_events, [:event_id]))
    create_if_not_exists(index(:trajectory_events, [:session_id, :at]))
    create_if_not_exists(index(:trajectory_events, [:type]))

    create_if_not_exists table(:eval_states, primary_key: false) do
      add(:session_id, :text, primary_key: true)
      add(:state, :binary, null: false)
      add(:updated_at, :utc_datetime_usec, null: false)
    end

    create_if_not_exists table(:subagent_jobs, primary_key: false) do
      add(:id, :text, primary_key: true)
      add(:parent_session_id, :text)
      add(:child_session_id, :text)
      add(:task, :text, null: false)
      add(:role, :text)
      add(:model, :text)
      add(:status, :text, null: false)
      add(:result, :map)
      add(:error, :text)
      add(:started_at, :utc_datetime_usec, null: false)
      add(:finished_at, :utc_datetime_usec)
      add(:duration_ms, :integer)
    end

    create_if_not_exists(index(:subagent_jobs, [:parent_session_id]))
    create_if_not_exists(index(:subagent_jobs, [:child_session_id]))
    create_if_not_exists(index(:subagent_jobs, [:status]))
    create_if_not_exists(index(:subagent_jobs, [:started_at]))

    create_if_not_exists table(:subagent_schedules, primary_key: false) do
      add(:id, :text, primary_key: true)
      add(:task, :text, null: false)
      add(:role, :text)
      add(:parent_session_id, :text)
      add(:run_at, :utc_datetime_usec)
      add(:every_ms, :integer)
      add(:missed, :text, null: false, default: "skip")
      add(:opts, :map, null: false, default: %{})
      add(:next_run_at, :utc_datetime_usec)
      add(:cancelled_at, :utc_datetime_usec)
      add(:inserted_at, :utc_datetime_usec, null: false)
      add(:updated_at, :utc_datetime_usec, null: false)
    end

    create_if_not_exists(index(:subagent_schedules, [:cancelled_at]))

    create_if_not_exists table(:memories, primary_key: false) do
      add(:id, :text, primary_key: true)
      add(:scope_type, :text, null: false)
      add(:scope_id, :text)
      add(:text, :text, null: false)
      add(:metadata, :map, null: false, default: %{})
      add(:inserted_at, :utc_datetime_usec, null: false)
      add(:updated_at, :utc_datetime_usec, null: false)
    end

    create_if_not_exists(index(:memories, [:scope_type, :scope_id]))

    create_if_not_exists table(:telemetry_events) do
      add(:name, :text, null: false)
      add(:at, :utc_datetime_usec, null: false)
      add(:measurements, :map, null: false)
      add(:metadata, :map, null: false)
    end

    create_if_not_exists(index(:telemetry_events, [:name]))
    create_if_not_exists(index(:telemetry_events, [:at]))

    create_if_not_exists table(:imports, primary_key: false) do
      add(:id, :text, primary_key: true)
      add(:source, :text, null: false)
      add(:imported_at, :utc_datetime_usec, null: false)
      add(:metadata, :map, null: false, default: %{})
    end
  end
end
