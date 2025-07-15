# frozen_string_literal: true

module ClaudeSDK
  module Internal
    # Abstract transport interface for Claude communication
    #
    # @abstract Subclass and override {#connect}, {#disconnect}, {#send_request},
    #   {#receive_messages}, and {#connected?} to implement a transport
    class Transport
      # Initialize connection
      #
      # @abstract
      # @return [void]
      def connect
        raise NotImplementedError, "#{self.class}#connect not implemented"
      end

      # Close connection
      #
      # @abstract
      # @return [void]
      def disconnect
        raise NotImplementedError, "#{self.class}#disconnect not implemented"
      end

      # Send request to Claude
      #
      # @abstract
      # @param messages [Array<Hash>] the messages to send
      # @param options [Hash] additional options
      # @return [void]
      def send_request(messages, options)
        raise NotImplementedError, "#{self.class}#send_request not implemented"
      end

      # Receive messages from Claude
      #
      # @abstract
      # @return [Enumerator<Hash>] yields message hashes
      def receive_messages
        raise NotImplementedError, "#{self.class}#receive_messages not implemented"
      end

      # Check if transport is connected
      #
      # @abstract
      # @return [Boolean] true if connected
      def connected?
        raise NotImplementedError, "#{self.class}#connected? not implemented"
      end
    end
  end
end
