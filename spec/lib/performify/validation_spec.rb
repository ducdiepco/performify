require 'spec_helper'

RSpec.describe Performify::Base do
  let(:user) { double(:user) }
  let(:args) do
    {
      foo: 'bar'
    }
  end

  let(:klass) do
    Class.new(described_class) do
      schema do
        required(:foo).filled(:str?)
      end

      def execute!
        super { true }
      end
    end
  end

  subject { klass.new(user, args) }

  after { klass.clean_callbacks }

  describe '#errors!' do
    it 'creates errors hash' do
      error = { user_id: 'is invalid' }
      subject.errors!(error)
      expect(subject.errors).to eq(error)
    end

    it 'merges new errors to existing hash' do
      error_1 = { user_id: 'is invalid' }
      error_2 = { password: 'is too easy' }

      subject.errors!(error_1)
      subject.errors!(error_2)

      expect(subject.errors).to eq(error_1.merge(error_2))
    end

    it 'deep merge new errors to existing hash' do
      messages = ['less than 6 characters', 'is too easy', ['is too easy']]
      messages.each { |message| subject.errors!({ password: message }) }

      expect(subject.errors).to eq({ password: messages.flatten(1) })
    end

    it 'converts argument to hash' do
      error = [ [:user_id, 'is invalid'] ]
      subject.errors!(error)
      expect(subject.errors).to eq(user_id: 'is invalid')
    end

    it 'raises ArgumentError if argument is nil' do
      expect { subject.errors!(nil) }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError if argument is not a hash' do
      error = 'Very bad situation'
      expect { subject.errors!(error) }.to raise_error(ArgumentError)
    end
  end

  describe '#initialize' do
    it 'validates given args using defined schema without errors' do
      expect(subject.errors).to be_empty
    end

    it 'allows to successfully execute without any problems' do
      subject.execute!
      expect(subject.success?).to be true
    end

    it 'has filtered inputs' do
      subject.execute!
      expect(subject.inputs).to eq(args)
    end

    context 'when args are invalid' do
      let(:args) do
        {
          foo: nil
        }
      end

      it 'validates given args and provides access to errors' do
        expect(subject.errors).to be_present
      end

      it 'mark execution as failed even before execution call' do
        expect(subject.fail?).to be true
      end

      it 'ignores all attempts of service execution' do
        subject.execute!
        expect(subject.success?).to be false
      end

      it 'no filtered inputs' do
        subject.execute!
        expect(subject.inputs).to be_nil
      end

      context 'and when execution does not use super' do
        let(:klass) do
          Class.new(described_class) do
            schema do
              required(:foo).filled(:str?)
            end

            def execute!
              success!
            end
          end
        end

        it 'ignores all attempts of service execution' do
          subject.execute!
          expect(subject.success?).to be false
        end
      end
    end

    context 'with outer schema' do
      let(:klass) do
        outer_schema = Dry::Validation.Schema do
          required(:foo).filled(:str?)
        end

        Class.new(described_class) do
          schema outer_schema

          def execute!
            super { true }
          end
        end
      end

      it 'executes successfully when args are valid' do
        subject.execute!
        expect(subject.success?).to be true
      end

      it 'has filtered inputs' do
        subject.execute!
        expect(subject.inputs).to eq(args)
      end

      context 'when args are invalid' do
        let(:args) do
          {
            foo: nil
          }
        end

        it 'executes fails' do
          subject.execute!
          expect(subject.success?).to be false
        end

        it 'no filtered inputs' do
          subject.execute!
          expect(subject.inputs).to be_nil
        end
      end
    end

    context '#with_options' do
      let(:user) { double(:user, foo: 'bar') }

      let(:klass) do
        Class.new(described_class) do
          schema do
            configure do
              option :current_user

              def self.messages
                super.merge(en: { errors: { valid?: 'foo invalid' } })
              end

              def valid?(value)
                current_user.foo == value
              end
            end

            required(:foo).filled(:str?, :valid?)
          end

          def execute!
            super { true }
          end
        end
      end

      context 'foo valid' do
        it 'no errors' do
          expect(subject.errors).to eq({})
        end
      end

      context 'foo invalid' do
        let(:user) { double(:user, foo: 'bar_foo') }

        it 'should return error' do
          expect(subject.errors).to eq({ foo: ['foo invalid'] })
        end
      end

      context 'override' do
        let(:klass) do
          Class.new(described_class) do
            schema do
              configure do
                option :user

                def self.messages
                  super.merge(en: { errors: { valid?: 'foo invalid' } })
                end

                def valid?(value)
                  user.foo == value
                end
              end

              required(:foo).filled(:str?, :valid?)
            end

            def execute!
              super { true }
            end

            private

            def with_options
              { user: current_user}
            end
          end
        end

        context 'foo valid' do
          it 'no errors' do
            expect(subject.errors).to eq({})
          end
        end

        context 'foo invalid' do
          let(:user) { double(:user, foo: 'bar_foo') }

          it 'should return error' do
            expect(subject.errors).to eq({ foo: ['foo invalid'] })
          end
        end
      end
    end
  end
end
