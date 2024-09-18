module SGS

    using Transformers
    using Flux
    using Flux.Optimise: ADAM
    using JLD2

    # # Function to calculate loss
    # function calculate_loss(model, data)
    #     total_loss = 0.0
    #     for (x, y) in data
    #         total_loss += loss_fn(model(x), y)
    #     end
    #     return total_loss / length(data)
    # end

    # # Function to fine-tune the model
    # function fine_tune_model!(model, data, epochs, opt)
    #     for epoch in 1:epochs
    #         for (x, y) in data
    #             gs = gradient(() -> loss_fn(model(x), y), params(model))
    #             Flux.Optimise.update!(opt, params(model), gs)
    #         end
    #         println("Epoch $epoch completed")
    #     end
    # end

    # Define loss function and optimizer
    loss_fn = Flux.logitcrossentropy
    opt = ADAM()

    # Function to calculate loss
    function calculate_loss(model, data)
        total_loss = 0.0
        for (x, y) in data
            hidden_state, attention_mask = x
            total_loss += loss_fn(model((hidden_state, attention_mask)), y)
        end
        return total_loss / length(data)
    end

    # Function to fine-tune the model
    function fine_tune_model!(model, data, epochs, opt)
        for epoch in 1:epochs
            for (x, y) in data
                hidden_state, attention_mask = x
                gs = gradient(() -> loss_fn(model((hidden_state, attention_mask)), y), params(model))
                Flux.Optimise.update!(opt, params(model), gs)
            end
            println("Epoch $epoch completed")
        end
    end

    # Define your functions
    function embedding(input)
        we = word_embed(input.token)
        pe = pos_embed(we)
        return we .+ pe
    end

    function encoder_forward(input)
        attention_mask = get(input, :attention_mask, nothing)
        e = embedding(input)
        t = encoder_trf(e, attention_mask) # return a NamedTuples (hidden_state = ..., ...)
        return t.hidden_state
    end

    function decoder_forward(input, m)
        attention_mask = get(input, :attention_mask, nothing)
        cross_attention_mask = get(input, :cross_attention_mask, nothing)
        e = embedding(input)
        t = decoder_trf(e, m, attention_mask, cross_attention_mask) # return a NamedTuple (hidden_state = ..., ...)
        p = embed_decode(t.hidden_state)
        return p
    end
end