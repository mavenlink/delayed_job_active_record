require "active_record"
require "delayed_job"
require "delayed/backend/active_record"

Delayed::Worker.backend = Delayed::Backend::ActiveRecord::NoNewrelicSamplerJob
