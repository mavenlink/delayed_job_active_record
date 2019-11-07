# frozen_string_literal: true

require "helper"
require "delayed/backend/active_record"

describe Delayed::Backend::ActiveRecord::Job do
  it_behaves_like "a delayed_job backend"

  describe "configuration" do
    describe "reserve_sql_strategy" do
      let(:configuration) { Delayed::Backend::ActiveRecord.configuration }

      it "allows :optimized_sql" do
        configuration.reserve_sql_strategy = :optimized_sql
        expect(configuration.reserve_sql_strategy).to eq(:optimized_sql)
      end

      it "allows :default_sql" do
        configuration.reserve_sql_strategy = :default_sql
        expect(configuration.reserve_sql_strategy).to eq(:default_sql)
      end

      it "allows :racerpeter_sql" do
        configuration.reserve_sql_strategy = :racerpeter_sql
        expect(configuration.reserve_sql_strategy).to eq(:racerpeter_sql)
      end

      it "allows :redis_sql_alt" do
        configuration.reserve_sql_strategy = :redis_sql_alt
        expect(configuration.reserve_sql_strategy).to eq(:redis_sql_alt)
      end

      it "raises an argument error on invalid entry" do
        expect { configuration.reserve_sql_strategy = :invalid }.to raise_error(ArgumentError)
      end
    end
  end

  describe "reserve_with_scope" do
    let(:relation_class) { Delayed::Job.limit(1).class }
    let(:worker) { instance_double(Delayed::Worker, name: "worker01", read_ahead: 1) }
    let(:job_id) { 1 }
    let(:sql) { "" }
    let(:job) { instance_double(Delayed::Job, id: job_id, update: true) }

    let(:detect) { -> { yield job_id } }
    let(:where) { instance_double(relation_class, update_all: 0) }
    let(:select) { instance_double(relation_class, to_sql: sql) }

    let(:pluck) { instance_double(Array, detect: detect) }
    let(:lock) { instance_double(relation_class, select: select) }
    let(:limit) do
      instance_double(relation_class, update_all: 0, lock: lock, to_sql: sql, pluck: pluck, detect: detect)
    end
    let(:scope) { instance_double(relation_class, limit: limit, where: where, first: job) }
    let(:reserve_sql_strategy) { :optimized_sql }

    before do
      allow(Delayed::Backend::ActiveRecord::Job.connection).to receive(:adapter_name).at_least(:once).and_return(dbms)
      Delayed::Backend::ActiveRecord.configuration.reserve_sql_strategy = reserve_sql_strategy
    end

    context "with reserve_sql_strategy option set to :optimized_sql (default)" do
      let(:reserve_sql_strategy) { :optimized_sql }

      context "for mysql adapters" do
        let(:dbms) { "MySQL" }

        it "uses the optimized sql version" do
          allow(Delayed::Backend::ActiveRecord::Job).to receive(:reserve_with_scope_using_default_sql)
          Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
          expect(Delayed::Backend::ActiveRecord::Job).not_to have_received(:reserve_with_scope_using_default_sql)
        end
      end

      context "for PostgreSQL adapters" do
        let(:dbms) { "PostgreSQL" }

        it "uses the optimized sql version" do
          allow(Delayed::Backend::ActiveRecord::Job).to receive(:reserve_with_scope_using_optimized_postgres)
          Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
          expect(Delayed::Backend::ActiveRecord::Job).to have_received(:reserve_with_scope_using_optimized_postgres)
        end
      end

      context "for PostGIS adapters" do
        let(:dbms) { "PostGIS" }

        it "uses the optimized sql version" do
          allow(Delayed::Backend::ActiveRecord::Job).to receive(:reserve_with_scope_using_optimized_postgres)
          Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
          expect(Delayed::Backend::ActiveRecord::Job).to have_received(:reserve_with_scope_using_optimized_postgres)
        end
      end

      context "for MSSQL adapters" do
        let(:dbms) { "MSSQL" }

        it "uses the optimized sql version" do
          allow(Delayed::Backend::ActiveRecord::Job).to receive(:reserve_with_scope_using_optimized_mssql)
          Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
          expect(Delayed::Backend::ActiveRecord::Job).to have_received(:reserve_with_scope_using_optimized_mssql)
        end
      end

      context "for Teradata adapters" do
        let(:dbms) { "Teradata" }

        it "uses the optimized sql version" do
          allow(Delayed::Backend::ActiveRecord::Job).to receive(:reserve_with_scope_using_optimized_mssql)
          Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
          expect(Delayed::Backend::ActiveRecord::Job).to have_received(:reserve_with_scope_using_optimized_mssql)
        end
      end

      context "for a dbms without a specific implementation" do
        let(:dbms) { "OtherDB" }

        it "uses the plain sql version" do
          allow(Delayed::Backend::ActiveRecord::Job).to receive(:reserve_with_scope_using_default_sql)
          Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
          expect(Delayed::Backend::ActiveRecord::Job).to have_received(:reserve_with_scope_using_default_sql).once
        end
      end
    end

    context "with reserve_sql_strategy option set to :default_sql" do
      let(:dbms) { "MySQL" }
      let(:reserve_sql_strategy) { :default_sql }

      it "uses the plain sql version" do
        allow(Delayed::Backend::ActiveRecord::Job).to receive(:reserve_with_scope_using_default_sql).and_call_original
        Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
        expect(Delayed::Backend::ActiveRecord::Job).to have_received(:reserve_with_scope_using_default_sql).once
      end
    end

    context "with reserve_sql_strategy option set to :racerpeter_sql" do
      let(:dbms) { "MySQL" }
      let(:reserve_sql_strategy) { :racerpeter_sql }

      it "uses the racerpeter sql version" do
        allow(
          Delayed::Backend::ActiveRecord::Job
        ).to receive(:reserve_with_scope_using_racerpeter_sql).and_call_original
        Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
        expect(Delayed::Backend::ActiveRecord::Job).to have_received(:reserve_with_scope_using_racerpeter_sql).once
      end
    end

    context "with reserve_sql_strategy option set to :redis_sql" do
      let(:dbms) { "MySQL" }
      let(:reserve_sql_strategy) { :redis_sql_alt }

      it "uses the plain sql version" do
        allow(Delayed::Backend::ActiveRecord::Job).to receive(:reserve_with_scope_using_redis_sql_alt).and_call_original
        Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current)
        expect(Delayed::Backend::ActiveRecord::Job).to have_received(:reserve_with_scope_using_redis_sql_alt).once
      end
    end

    context "with reserve_with_scope option set to a invalid value" do
      let(:dbms) { "MySQL" }
      let(:invalid_reserve_sql_strategy) { :invalid }

      before do
        allow(Delayed::Backend::ActiveRecord).to receive(:configuration)
          .and_return(OpenStruct.new(reserve_sql_strategy: invalid_reserve_sql_strategy))
      end

      it "raises an error" do
        expect { Delayed::Backend::ActiveRecord::Job.reserve_with_scope(scope, worker, Time.current) }
          .to raise_error(RuntimeError)
      end
    end
  end

  context "db_time_now" do
    after do
      Time.zone = nil
      ActiveRecord::Base.default_timezone = :local
    end

    it "returns time in current time zone if set" do
      Time.zone = "Arizona"
      expect(Delayed::Job.db_time_now.zone).to eq("MST")
    end

    it "returns UTC time if that is the AR default" do
      Time.zone = nil
      ActiveRecord::Base.default_timezone = :utc
      expect(Delayed::Backend::ActiveRecord::Job.db_time_now.zone).to eq "UTC"
    end

    it "returns local time if that is the AR default" do
      Time.zone = "Arizona"
      ActiveRecord::Base.default_timezone = :local
      expect(Delayed::Backend::ActiveRecord::Job.db_time_now.zone).to eq("MST")
    end
  end

  describe "before_fork" do
    it "calls clear_all_connections!" do
      allow(ActiveRecord::Base).to receive(:clear_all_connections!)
      Delayed::Backend::ActiveRecord::Job.before_fork
      expect(ActiveRecord::Base).to have_received(:clear_all_connections!)
    end
  end

  describe "after_fork" do
    it "calls reconnect on the connection" do
      allow(ActiveRecord::Base).to receive(:establish_connection)
      Delayed::Backend::ActiveRecord::Job.after_fork
      expect(ActiveRecord::Base).to have_received(:establish_connection)
    end
  end

  describe "enqueue" do
    it "allows enqueue hook to modify job at DB level" do
      later = described_class.db_time_now + 20.minutes
      job = Delayed::Backend::ActiveRecord::Job.enqueue payload_object: EnqueueJobMod.new
      expect(Delayed::Backend::ActiveRecord::Job.find(job.id).run_at).to be_within(1).of(later)
    end
  end

  if ::ActiveRecord::VERSION::MAJOR < 4 || defined?(::ActiveRecord::MassAssignmentSecurity)
    it "allows mass assignment" do
      expect(Delayed::Backend::ActiveRecord::Job.accessible_attributes).to include(
        :priority,
        :run_at,
        :queue,
        :payload_object,
        :failed_at,
        :locked_at,
        :locked_by,
        :handler
      )
    end

    context "ActiveRecord::Base.send(:attr_accessible, nil)" do
      before do
        Delayed::Backend::ActiveRecord::Job.send(:attr_accessible, nil)
      end

      after do
        Delayed::Backend::ActiveRecord::Job.send(
          :attr_accessible,
          *Delayed::Backend::ActiveRecord::Job.new.attributes.keys
        )
      end

      it "is still accessible" do
        job = Delayed::Backend::ActiveRecord::Job.enqueue payload_object: EnqueueJobMod.new
        expect(Delayed::Backend::ActiveRecord::Job.find(job.id).handler).not_to be_blank
      end
    end
  end

  context "ActiveRecord::Base.table_name_prefix" do
    it "when prefix is not set, use 'delayed_jobs' as table name" do
      ::ActiveRecord::Base.table_name_prefix = nil
      Delayed::Backend::ActiveRecord::Job.set_delayed_job_table_name

      expect(Delayed::Backend::ActiveRecord::Job.table_name).to eq "delayed_jobs"
    end

    it "when prefix is set, prepend it before default table name" do
      ::ActiveRecord::Base.table_name_prefix = "custom_"
      Delayed::Backend::ActiveRecord::Job.set_delayed_job_table_name

      expect(Delayed::Backend::ActiveRecord::Job.table_name).to eq "custom_delayed_jobs"

      ::ActiveRecord::Base.table_name_prefix = nil
      Delayed::Backend::ActiveRecord::Job.set_delayed_job_table_name
    end
  end
end
