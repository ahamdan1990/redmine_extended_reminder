require_dependency 'mailer'

module RedmineExtendedReminder
  module MailerModelPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        # replace class methods
        helper :extended_reminder
        class << self
          alias_method :reminders_without_patch, :reminders
          alias_method :reminders, :reminders_with_patch
        end

        # replace instance methods
        alias_method :reminder_without_patch, :reminder
        alias_method :reminder, :reminder_with_patch
      end
    end
  end

  module ClassMethods
    def reminders_with_patch(options={})
      # Non-working days setting is supported in Redmine 2.2 or higher.
      if Redmine::VERSION.to_a[0..1].join('.').to_f >= 2.2
        if Setting.plugin_redmine_extended_reminder[:disable_on_non_woking_days].to_i != 0
          date_calc = Object.new
          date_calc.extend Redmine::Utils::DateCalculation
          return nil if date_calc.non_working_week_days.include?(Date.today.wday)
        end
      end

      days_override = Setting.plugin_redmine_extended_reminder[:days].to_i
      options[:days] = days_override if days_override > 0
      reminders_without_patch(options)
    end
  end

  module InstanceMethods
    def reminder_with_patch(user, issues, days)
      saved_status = ActionMailer::Base.perform_deliveries
      if user.pref[:extended_reminder_no_reminders]
        ActionMailer::Base.perform_deliveries = false
      end
      @issues_by_date = issues.sort_by(&:due_date).group_by(&:due_date)
      @count = issues.size
      reminder_without_patch(user, issues, days)
    ensure
      ActionMailer::Base.perform_deliveries = saved_status
    end
  end
end

unless Mailer.included_modules.include?(RedmineExtendedReminder::MailerModelPatch)
  Mailer.send(:include, RedmineExtendedReminder::MailerModelPatch)
end