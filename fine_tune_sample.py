from transformers import AutoTokenizer, AutoModelForCausalLM, Trainer, TrainingArguments

def fine_tune_model(texts):
    # Initialize the tokenizer and model
    tokenizer = AutoTokenizer.from_pretrained("openai-community/gpt2")
    
    # Set the padding token
    tokenizer.pad_token = tokenizer.eos_token
    
    model = AutoModelForCausalLM.from_pretrained("openai-community/gpt2")

    # Tokenize the input texts with truncation and padding
    inputs = tokenizer(texts, return_tensors="pt", add_special_tokens=True, padding=True, truncation=True)

    # Define training arguments
    training_args = TrainingArguments(
        output_dir="./results",
        num_train_epochs=1,
        per_device_train_batch_size=2,
        save_steps=10_000,
        save_total_limit=2,
    )

    # Initialize the Trainer
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=inputs["input_ids"],
    )

    # Train the model
    trainer.train()