module BW
  class UIAlertView < ::UIAlertView
    @callbacks = [
      :will_present,
      :did_present,
      :on_system_cancel,
      :enable_first_other_button?,
      :on_click,
      :will_dismiss,
      :did_dismiss
    ]

    KEYBOARD_TYPES = {
      default: UIKeyboardTypeDefault,
      ascii: UIKeyboardTypeASCIICapable,
      numbers_punctuation: UIKeyboardTypeNumbersAndPunctuation,
      url: UIKeyboardTypeURL,
      number_pad: UIKeyboardTypeNumberPad,
      phone_pad: UIKeyboardTypePhonePad,
      name_phone_pad: UIKeyboardTypeNamePhonePad,
      email_address: UIKeyboardTypeEmailAddress,
      email: UIKeyboardTypeEmailAddress, # Duplicate to help developers
      decimal_pad: UIKeyboardTypeDecimalPad,
      twitter: UIKeyboardTypeTwitter,
      web_search: UIKeyboardTypeWebSearch,
      alphabet: UIKeyboardTypeASCIICapable
    }

    class << self
      attr_reader :callbacks

      def new(options = {}, &block)
        view = alloc.initWithTitle(options[:title],
          message: options[:message],
          delegate: nil,
          cancelButtonTitle: nil,
          otherButtonTitles: nil
        )

        Array(options[:buttons]).each { |title| view.addButtonWithTitle(title) }

        view.style               = options[:style]
        view.delegate            = view
        view.cancel_button_index = options[:cancel_button_index]

        view.instance_variable_set(:@handlers, {})
        block.weak! if block && BubbleWrap.use_weak_callbacks?

        options[:on_click] ||= block

        callbacks.each do |callback|
          view.send(callback, &options[callback]) if options[callback]
        end

        view
      end

      def default(options = {}, &block)
        options = {buttons: "OK"}.merge!(options)
        options[:style] = :default
        new(options, &block)
      end

      def plain_text_input(options = {}, &block)
        options = {buttons: ["Cancel", "OK"],
                   cancel_button_index: 0}.merge!(options)
        options[:style] = :plain_text_input
        new(options, &block).tap do |view|
          view.textFieldAtIndex(0).tap do |tf|
            tf.text = options[:text] if options[:text]
            tf.placeholder = options[:placeholder] if options[:placeholder]
            tf.keyboardType = (KEYBOARD_TYPES[options[:keyboard_type]] || options[:keyboard_type]) if options[:keyboard_type]
          end
        end
      end

      def secure_text_input(options = {}, &block)
        options = {buttons: ["Cancel", "OK"],
                   cancel_button_index: 0}.merge!(options)
        options[:style] = :secure_text_input
        new(options, &block)
      end

      def login_and_password_input(options = {}, &block)
        options = {buttons: ["Cancel", "Log in"],
                   cancel_button_index: 0}.merge!(options)
        options[:style] = :login_and_password_input
        new(options, &block)
      end
    end

    def style
      alertViewStyle
    end

    def style=(value)
      self.alertViewStyle = Constants.get("UIAlertViewStyle", value) if value
    end

    def cancel_button_index
      cancelButtonIndex
    end

    def cancel_button_index=(value)
      self.cancelButtonIndex = value if value
    end

    ###############################################################################################

    attr_accessor :clicked_button
    protected     :clicked_button=

    class ClickedButton
      def initialize(alert, index)
        @index  = index
        @title  = alert.buttonTitleAtIndex(index)
        @cancel = alert.cancelButtonIndex == index
      end

      attr_reader :index, :title
      def cancel?; @cancel end
    end

    ###############################################################################################

    attr_reader :handlers
    protected   :handlers

    callbacks.each do |callback|
      define_method(callback) do |&block|
        return handlers[callback] unless block

        handlers[callback] = block if block
        self
      end
    end

    # UIAlertViewDelegate protocol ################################################################

    def willPresentAlertView(alert)
      alert.clicked_button = nil
      handlers[:will_present].call(alert) if handlers[:will_present]
    end

    def didPresentAlertView(alert)
      alert.clicked_button = nil
      handlers[:did_present].call(alert) if handlers[:did_present]
    end

    def alertViewCancel(alert)
      alert.clicked_button = nil
      handlers[:on_system_cancel].call(alert) if handlers[:on_system_cancel]
    end

    def alertViewShouldEnableFirstOtherButton(alert)
      alert.clicked_button = nil
      handlers[:enable_first_other_button?].call(alert) if handlers[:enable_first_other_button?]
    end

    def alertView(alert, clickedButtonAtIndex:index)
      alert.clicked_button = ClickedButton.new(alert, index)
      handlers[:on_click].call(alert) if handlers[:on_click]
    end

    def alertView(alert, willDismissWithButtonIndex:index)
      alert.clicked_button = ClickedButton.new(alert, index)
      handlers[:will_dismiss].call(alert) if handlers[:will_dismiss]
    end

    def alertView(alert, didDismissWithButtonIndex:index)
      alert.clicked_button = ClickedButton.new(alert, index)
      handlers[:did_dismiss].call(alert) if handlers[:did_dismiss]
    end

    ###############################################################################################

    def plain_text_field
      textFieldAtIndex(0) if style == UIAlertViewStylePlainTextInput
    end

    def secure_text_field
      textFieldAtIndex(0) if style == UIAlertViewStyleSecureTextInput
    end

    def login_text_field
      textFieldAtIndex(0) if style == UIAlertViewStyleLoginAndPasswordInput
    end

    def password_text_field
      textFieldAtIndex(1) if style == UIAlertViewStyleLoginAndPasswordInput
    end
  end

  Constants.register(
    UIAlertViewStyleDefault,
    UIAlertViewStylePlainTextInput,
    UIAlertViewStyleSecureTextInput,
    UIAlertViewStyleLoginAndPasswordInput
  )
end
